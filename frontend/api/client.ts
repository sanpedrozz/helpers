import axios from "axios";
import { useAuth } from "@/store/auth";

export const api = axios.create({ baseURL: import.meta.env.VITE_API_URL, withCredentials: true });

api.interceptors.request.use((cfg) => {
  const token = useAuth.getState().access;
  if (token) cfg.headers.Authorization = `Bearer ${token}`;
  return cfg;
});

// auto-refresh access token on 401
api.interceptors.response.use(undefined, async (err) => {
  if (err.response?.status === 401 && !err.config._retried) {
    err.config._retried = true;
    try {
      const { data } = await api.post("/auth/refresh");
      useAuth.getState().setAccess(data.access_token);
      err.config.headers.Authorization = `Bearer ${data.access_token}`;
      return api.request(err.config);
    } catch {
      useAuth.getState().setAccess(null);
      window.location.href = "/login";
    }
  }
  return Promise.reject(err);
});
