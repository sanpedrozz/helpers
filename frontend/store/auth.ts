import { create } from "zustand";

type AuthState = {
  access: string | null;
  setAccess: (t: string | null) => void;
};

export const useAuth = create<AuthState>((set) => ({
  access: null,
  setAccess: (t) => set({ access: t }),
}));
