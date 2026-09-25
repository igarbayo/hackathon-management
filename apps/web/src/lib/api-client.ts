const API_URL = process.env.NEXT_PUBLIC_API_URL ?? "http://localhost:3001";
const SAFE_METHODS = new Set(["GET", "HEAD", "OPTIONS"]);

export class ApiError extends Error {
  status: number;
  code?: string;
  details?: unknown;

  constructor(status: number, message: string, code?: string, details?: unknown) {
    super(message);
    this.status = status;
    this.code = code;
    this.details = details;
  }
}

type RequestOptions = Omit<RequestInit, "body"> & {
  body?: unknown;
};

// The backend requires X-CSRF-Token on every request that changes state
// (03-api.md#convenciones-generales). It is cached in memory per tab.
let csrfTokenPromise: Promise<string> | null = null;

async function fetchCsrfToken(): Promise<string> {
  const response = await fetch(`${API_URL}/api/v1/csrf`, { credentials: "include" });
  const payload = await response.json();
  return payload.csrf_token as string;
}

function getCsrfToken(): Promise<string> {
  csrfTokenPromise ??= fetchCsrfToken();
  return csrfTokenPromise;
}

async function performRequest(path: string, options: RequestOptions, csrfToken?: string): Promise<Response> {
  const { body, headers, ...rest } = options;

  return fetch(`${API_URL}${path}`, {
    ...rest,
    credentials: "include",
    headers: {
      "Content-Type": "application/json",
      Accept: "application/json",
      ...(csrfToken ? { "X-CSRF-Token": csrfToken } : {}),
      ...headers,
    },
    body: body !== undefined ? JSON.stringify(body) : undefined,
  });
}

async function parseResponse<T>(response: Response): Promise<T> {
  if (response.status === 204) {
    return undefined as T;
  }

  const isJson = response.headers.get("content-type")?.includes("application/json");
  const payload = isJson ? await response.json() : undefined;

  if (!response.ok) {
    const message = payload?.error?.message ?? response.statusText;
    const code = payload?.error?.code;
    throw new ApiError(response.status, message, code, payload?.error?.details);
  }

  return payload as T;
}

async function request<T>(path: string, options: RequestOptions = {}): Promise<T> {
  const method = (options.method ?? "GET").toUpperCase();

  if (SAFE_METHODS.has(method)) {
    return parseResponse<T>(await performRequest(path, options));
  }

  const token = await getCsrfToken();
  return parseResponse<T>(await performRequest(path, options, token));
}

export const apiClient = {
  get: <T>(path: string, options?: RequestOptions) => request<T>(path, { ...options, method: "GET" }),
  post: <T>(path: string, body?: unknown, options?: RequestOptions) =>
    request<T>(path, { ...options, method: "POST", body }),
  patch: <T>(path: string, body?: unknown, options?: RequestOptions) =>
    request<T>(path, { ...options, method: "PATCH", body }),
  put: <T>(path: string, body?: unknown, options?: RequestOptions) =>
    request<T>(path, { ...options, method: "PUT", body }),
  delete: <T>(path: string, options?: RequestOptions) => request<T>(path, { ...options, method: "DELETE" }),
};
