import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:appmantflutter/productos/lista_productos_screen.dart';
import 'package:appmantflutter/services/categorias_service.dart';
import 'package:appmantflutter/services/audit_service.dart';
import 'package:appmantflutter/shared/disciplinas_config.dart';
import 'package:appmantflutter/shared/text_formatters.dart';

class CategoriasDisciplinaScreen extends StatefulWidget {
  final String disciplinaId;
  final String disciplinaNombre;

  const CategoriasDisciplinaScreen({
    super.key,
    required this.disciplinaId,
    required this.disciplinaNombre,
  });

  @override
  State<CategoriasDisciplinaScreen> createState() => _CategoriasDisciplinaScreenState();
}

class _CategoriasDisciplinaScreenState extends State<CategoriasDisciplinaScreen> {
  final _categoriasService = CategoriasService.instance;
  bool _editMode = false;

  @override
  void initState() {
    super.initState();
    _categoriasService.ensureSeededForDisciplina(widget.disciplinaId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: Text(widget.disciplinaNombre),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(_editMode ? Icons.check : Icons.edit),
            tooltip: _editMode ? 'Finalizar edición' : 'Editar categorías',
            onPressed: () => setState(() => _editMode = !_editMode),
          ),
        ],
      ),
      body: StreamBuilder<List<CategoriaItem>>(
        stream: _categoriasService.streamByDisciplina(widget.disciplinaId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final categorias = snapshot.data ?? const <CategoriaItem>[];
          if (categorias.isEmpty) {
            return _EmptyCategoriasState(
              editMode: _editMode,
              onNueva: () => _openCategoriaEditor(context, categoria: null),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
            itemCount: categorias.length + (_editMode ? 1 : 0),
            separatorBuilder: (_, __) => const SizedBox(height: 15),
            itemBuilder: (context, index) {
              if (_editMode && index == categorias.length) {
                return _NuevaCategoriaTile(onTap: () => _openCategoriaEditor(context, categoria: null));
              }
              final item = categorias[index];
              return _CategoriaCard(
                categoria: item,
                color: primaryRed,
                editMode: _editMode,
                onTap: _editMode
                    ? null
                    : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ListaProductosScreen(
                              filterBy: 'categoria',
                              filterValue: item.value,
                              title: item.label,
                              disciplinaKey: widget.disciplinaId,
                              categoriaValue: item.value,
                            ),
                          ),
                        );
                      },
                onEdit: () => _openCategoriaEditor(context, categoria: item),
                onDelete: () => _confirmDeleteCategoria(context, item),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _confirmDeleteCategoria(BuildContext context, CategoriaItem item) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar categoría'),
        content: Text('¿Seguro que deseas eliminar "${item.label}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (shouldDelete != true) return;

    final productosRef = FirebaseFirestore.instance.collection('productos');
    final snapshotCategoria = await productosRef.where('categoria', isEqualTo: item.value).limit(1).get();
    final snapshotCategoriaActivo =
        await productosRef.where('categoriaActivo', isEqualTo: item.value).limit(1).get();
    if (snapshotCategoria.docs.isNotEmpty || snapshotCategoriaActivo.docs.isNotEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Para eliminar esta categoría, primero debes dejarla sin activos.')),
        );
      }
      return;
    }

    await _categoriasService.deleteCategoria(item.id);
    await AuditService.logEvent(
      action: 'category.delete',
      message: 'eliminó la categoría "${item.label}"',
      disciplina: widget.disciplinaId,
      categoria: item.value,
      meta: {
        'before': {
          'label': item.label,
          'icon': _iconLabel(item.icon),
        },
      },
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Categoría "${item.label}" eliminada.')),
      );
    }
  }

  Future<void> _openCategoriaEditor(BuildContext context, {CategoriaItem? categoria}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CategoriaEditorScreen(
          disciplinaId: widget.disciplinaId,
          disciplinaNombre: widget.disciplinaNombre,
          categoria: categoria,
        ),
      ),
    );
  }
}

class _CategoriaCard extends StatelessWidget {
  final CategoriaItem categoria;
  final Color color;
  final bool editMode;
  final VoidCallback? onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CategoriaCard({
    required this.categoria,
    required this.color,
    required this.editMode,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
            child: Row(
              children: [
                Icon(categoria.icon, size: 30, color: color),
                const SizedBox(width: 20),
                Expanded(
                  child: Text(
                    categoria.label,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                ),
                if (editMode) ...[
                  IconButton(
                    icon: const Icon(Icons.edit, color: Color(0xFF8B1E1E)),
                    tooltip: 'Editar',
                    onPressed: onEdit,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.redAccent),
                    tooltip: 'Eliminar',
                    onPressed: onDelete,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NuevaCategoriaTile extends StatelessWidget {
  final VoidCallback onTap;

  const _NuevaCategoriaTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
          color: Colors.white,
        ),
        child: Row(
          children: const [
            Icon(Icons.add_circle_outline, color: Color(0xFF8B1E1E)),
            SizedBox(width: 12),
            Text(
              'Nueva Categoría',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF2C3E50)),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCategoriasState extends StatelessWidget {
  final bool editMode;
  final VoidCallback onNueva;

  const _EmptyCategoriasState({required this.editMode, required this.onNueva});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('No hay categorías para esta disciplina.'),
          const SizedBox(height: 12),
          if (editMode)
            ElevatedButton(
              onPressed: onNueva,
              child: const Text('Crear primera categoría'),
            ),
        ],
      ),
    );
  }
}

class CategoriaEditorScreen extends StatefulWidget {
  final String disciplinaId;
  final String disciplinaNombre;
  final CategoriaItem? categoria;

  const CategoriaEditorScreen({
    super.key,
    required this.disciplinaId,
    required this.disciplinaNombre,
    this.categoria,
  });

  @override
  State<CategoriaEditorScreen> createState() => _CategoriaEditorScreenState();
}

class _CategoriaEditorScreenState extends State<CategoriaEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _categoriasService = CategoriasService.instance;
  late IconData _selectedIcon;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nombreCtrl.text = widget.categoria?.label ?? '';
    _selectedIcon = widget.categoria?.icon ?? _categoriaIconOptions.first;
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.categoria != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Editar Categoría' : 'Nueva Categoría'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: primaryRed.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(_selectedIcon, size: 50, color: primaryRed),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Selecciona un ícono',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _categoriaIconOptions.map((icon) {
                final selected = icon == _selectedIcon;
                return InkWell(
                  onTap: _isSaving ? null : () => setState(() => _selectedIcon = icon),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: selected ? primaryRed.withOpacity(0.15) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: selected ? primaryRed : Colors.grey.shade300),
                    ),
                    child: Icon(icon, color: primaryRed),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nombreCtrl,
              decoration: const InputDecoration(
                labelText: 'Nombre de la categoría',
                border: OutlineInputBorder(),
              ),
              validator: (value) => value == null || value.trim().isEmpty ? 'Campo requerido' : null,
              enabled: !_isSaving,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isSaving ? null : _saveCategoria,
              child: Text(isEditing ? 'Guardar cambios' : 'Crear categoría'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveCategoria() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final label = _nombreCtrl.text.trim();
    try {
      if (widget.categoria == null) {
        final value = normalizeCategoriaValue(label);
        if (value.isEmpty) {
          throw Exception('Nombre inválido.');
        }
        final exists = await _categoriasService.existsValue(widget.disciplinaId, value);
        if (exists) {
          throw Exception('Ya existe una categoría con ese nombre.');
        }
        await _categoriasService.createCategoria(
          disciplinaKey: widget.disciplinaId,
          value: value,
          label: label,
          icon: _selectedIcon,
        );
        await AuditService.logEvent(
          action: 'category.create',
          message: 'creó la categoría "$label"',
          disciplina: widget.disciplinaId,
          categoria: value,
          meta: {
            'after': {
              'label': label,
              'icon': _iconLabel(_selectedIcon),
            },
          },
        );
      } else {
        final beforeLabel = widget.categoria!.label;
        final beforeIcon = _iconLabel(widget.categoria!.icon);
        final afterLabel = label;
        final afterIcon = _iconLabel(_selectedIcon);
        final changes = <String>[];
        if (beforeLabel != afterLabel) {
          changes.add('label');
        }
        if (beforeIcon != afterIcon) {
          changes.add('icon');
        }
        await _categoriasService.updateCategoria(
          categoriaId: widget.categoria!.id,
          label: label,
          icon: _selectedIcon,
        );
        if (changes.isNotEmpty) {
          final message = changes.length == 1 && changes.first == 'label'
              ? 'renombró categoría: "$beforeLabel" → "$afterLabel"'
              : changes.length == 1 && changes.first == 'icon'
                  ? 'actualizó ícono de la categoría "$afterLabel"'
                  : 'actualizó la categoría "$afterLabel"';
          await AuditService.logEvent(
            action: 'category.update',
            message: message,
            disciplina: widget.disciplinaId,
            categoria: widget.categoria!.value,
            changes: changes,
            meta: {
              'before': {
                'label': beforeLabel,
                'icon': beforeIcon,
              },
              'after': {
                'label': afterLabel,
                'icon': afterIcon,
              },
            },
          );
        }
      }
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}

const List<IconData> _categoriaIconOptions = [
  Icons.lightbulb,
  Icons.smart_toy,
  Icons.flash_on,
  Icons.format_paint,
  Icons.door_front_door,
  Icons.view_column,
  Icons.cyclone,
  Icons.water_drop,
  Icons.chair,
  Icons.table_restaurant,
  Icons.inventory_2,
  Icons.build,
  Icons.construction,
  Icons.storage,
  Icons.widgets,
];

String _iconLabel(IconData icon) {
  if (icon == Icons.lightbulb) return 'lightbulb';
  if (icon == Icons.smart_toy) return 'smart_toy';
  if (icon == Icons.flash_on) return 'flash_on';
  if (icon == Icons.format_paint) return 'format_paint';
  if (icon == Icons.door_front_door) return 'door_front_door';
  if (icon == Icons.view_column) return 'view_column';
  if (icon == Icons.cyclone) return 'cyclone';
  if (icon == Icons.water_drop) return 'water_drop';
  if (icon == Icons.chair) return 'chair';
  if (icon == Icons.table_restaurant) return 'table_restaurant';
  if (icon == Icons.inventory_2) return 'inventory_2';
  if (icon == Icons.build) return 'build';
  if (icon == Icons.construction) return 'construction';
  if (icon == Icons.storage) return 'storage';
  if (icon == Icons.widgets) return 'widgets';
  return 'icon_${icon.codePoint}';
}
