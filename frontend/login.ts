import { api } from "@/api/client";
import { useAuth } from "@/store/auth";
import { router } from "@tanstack/router"; // placeholder import

export const onSubmit = async (email: string, password: string) => {
  const { data } = await api.post("/auth/login", { email, password });
  useAuth.getState().setAccess(data.access_token);
  router.navigate({ to: "/" });
};

export const logout = async () => {
  await api.post("/auth/logout");
  useAuth.getState().setAccess(null);
  router.navigate({ to: "/login" });
};
