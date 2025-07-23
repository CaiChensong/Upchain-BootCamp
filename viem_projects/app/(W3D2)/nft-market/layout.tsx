"use client";

import { ReactNode } from "react";
import { AppKitProvider } from "./appkit-config";

export default function Providers({ children }: { children: ReactNode }) {
  return <AppKitProvider>{children}</AppKitProvider>;
}
