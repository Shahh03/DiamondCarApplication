import axios, { type AxiosError, type InternalAxiosRequestConfig } from 'axios';
import { reportApiFailure } from './monitoring';

import {
  clearSession,
  readSession,
  writeSession,
  type PortalSession,
} from './session';

const baseURL =
  import.meta.env.VITE_API_BASE_URL?.toString().replace(/\/$/, '') ||
  'http://localhost:8000';

export const apiClient = axios.create({
  baseURL,
  timeout: 20_000,
  headers: { Accept: 'application/json', 'Content-Type': 'application/json' },
});

apiClient.interceptors.request.use((config) => {
  const accessToken = readSession()?.accessToken;
  if (accessToken) config.headers.Authorization = `Bearer ${accessToken}`;
  return config;
});

interface RetryableRequest extends InternalAxiosRequestConfig {
  _diamondCarRetried?: boolean;
}

let refreshPromise: Promise<string | null> | null = null;

async function refreshAccessToken(): Promise<string | null> {
  const session = readSession();
  if (!session?.refreshToken) return null;

  try {
    const response = await axios.post<PortalSession>(
      `${baseURL}/user/refresh`,
      { refreshToken: session.refreshToken },
      {
        timeout: 20_000,
        headers: { Accept: 'application/json', 'Content-Type': 'application/json' },
      },
    );
    const nextSession: PortalSession = {
      accessToken: response.data.accessToken,
      refreshToken: response.data.refreshToken,
      user: response.data.user,
    };
    writeSession(nextSession);
    return nextSession.accessToken;
  } catch (error) {
    if (axios.isAxiosError(error)) reportApiFailure(error.response?.status);
    clearSession();
    return null;
  }
}

apiClient.interceptors.response.use(
  (response) => response,
  async (error: AxiosError) => {
    reportApiFailure(error.response?.status);
    const request = error.config as RetryableRequest | undefined;
    const authenticationRoute =
      request?.url?.includes('/user/login') ||
      request?.url?.includes('/user/refresh') ||
      request?.url?.includes('/user/provider-signup');

    if (
      error.response?.status !== 401 ||
      !request ||
      request._diamondCarRetried ||
      authenticationRoute
    ) {
      return Promise.reject(error);
    }

    request._diamondCarRetried = true;
    refreshPromise ??= refreshAccessToken().finally(() => {
      refreshPromise = null;
    });
    const accessToken = await refreshPromise;
    if (!accessToken) return Promise.reject(error);
    request.headers.Authorization = `Bearer ${accessToken}`;
    return apiClient(request);
  },
);

export function apiErrorMessage(error: unknown, fallback: string): string {
  if (axios.isAxiosError(error)) {
    const data = error.response?.data as { message?: unknown } | undefined;
    if (typeof data?.message === 'string' && data.message.trim()) {
      return data.message.trim();
    }
    if (error.code === 'ECONNABORTED') {
      return 'The server took too long to respond. Please try again.';
    }
    if (!error.response) {
      return 'Could not connect to the server. Check that the API is running.';
    }
  }
  return fallback;
}
