"use client";
import React from "react";
type Dict = Record<string,string>;
const dictionaries: Record<string, Dict> = { en: { "nav.features":"Features" } };
type Ctx = { t:(k:string)=>string; locale:string; setLocale:(l:string)=>void };
const Ctx = React.createContext<Ctx>({ t:(k)=>k, locale:"en", setLocale:()=>{} });
export function I18nProvider({children}:{children:React.ReactNode}) {
  const [locale,setLocale]=React.useState("en");
  const t=React.useCallback((k:string)=> (dictionaries[locale]||dictionaries.en)[k] || dictionaries.en[k] || k,[locale]);
  return <Ctx.Provider value={{t,locale,setLocale}}>{children}</Ctx.Provider>;
}
export function useI18n(){ return React.useContext(Ctx); }