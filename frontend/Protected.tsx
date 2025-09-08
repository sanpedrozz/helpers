import { useEffect, useState } from "react";
import { Navigate } from "react-router-dom";
import { api } from "@/api/client";
import { useAuth } from "@/store/auth";

export function Protected({ children }: { children: JSX.Element }) {
  const access = useAuth((s) => s.access);
  const [ok, setOk] = useState<boolean | null>(access ? true : null);

  useEffect(() => {
    if (access) {
      setOk(true);
      return;
    }
    api
      .post("/auth/refresh")
      .then(({ data }) => {
        useAuth.getState().setAccess(data.access_token);
        setOk(true);
      })
      .catch(() => {
        setOk(false);
      });
  }, [access]);

  if (ok === null) return null;
  if (!ok) return <Navigate to="/login" replace />;
  return children;
}
