"use client";
import React from "react";

type Dict = Record<string,string>;
const dictionaries: Record<string, Dict> = {
  en: { "cta.startFree": "Start Free" },
  es: { "cta.startFree": "Comienza gratis" },
  fr: { "cta.startFree": "Commencer gratuitement" },
  de: { "cta.startFree": "Kostenlos starten" },
};

type Ctx = { t:(k:string)=>string; locale:string; setLocale:(l:string)=>void };
const I18nContext = React.createContext<Ctx>({ t:(k)=>k, locale:"en", setLocale:()=>{} });

export function I18nProvider({ children }:{ children: React.ReactNode }) {
  const initial =
    (typeof window !== "undefined" &&
      (new URLSearchParams(window.location.search).get("lang") || localStorage.getItem("lang"))) || "en";
  const [locale, setLocale] = React.useState<string>(initial);
  const t = React.useCallback(
    (k:string) => (dictionaries[locale] || dictionaries.en)[k] || dictionaries.en[k] || k,
    [locale]
  );
  React.useEffect(() => { if (typeof window !== "undefined") localStorage.setItem("lang", locale); }, [locale]);
  return <I18nContext.Provider value={{ t, locale, setLocale }}>{children}</I18nContext.Provider>;
}

export function useI18n(){ return React.useContext(I18nContext); }