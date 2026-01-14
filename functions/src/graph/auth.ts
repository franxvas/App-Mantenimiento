import axios from "axios";
import { getGraphConfig } from "../config";

let cachedToken: { token: string; expiresAt: number } | null = null;

export const getAccessToken = async (): Promise<string> => {
  const now = Date.now();
  if (cachedToken && now < cachedToken.expiresAt - 60_000) {
    return cachedToken.token;
  }

  const { tenantId, clientId, clientSecret } = getGraphConfig();
  const tokenUrl = `https://login.microsoftonline.com/${tenantId}/oauth2/v2.0/token`;
  const body = new URLSearchParams({
    client_id: clientId,
    client_secret: clientSecret,
    scope: "https://graph.microsoft.com/.default",
    grant_type: "client_credentials"
  });

  const response = await axios.post(tokenUrl, body.toString(), {
    headers: {
      "Content-Type": "application/x-www-form-urlencoded"
    }
  });

  const { access_token: accessToken, expires_in: expiresIn } = response.data as {
    access_token: string;
    expires_in: number;
  };

  cachedToken = {
    token: accessToken,
    expiresAt: now + expiresIn * 1000
  };

  return accessToken;
};
