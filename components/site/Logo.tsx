
import React from 'react';
export function Logo({className}:{className?:string}){
  return (
    <div className={className||''} aria-label="Truvern logo">
      <svg width="28" height="28" viewBox="0 0 28 28" fill="none" xmlns="http://www.w3.org/2000/svg">
        <rect width="28" height="28" rx="6" fill="#0f172a"/>
        <path d="M7 9h14v2H15v8h-2v-8H7z" fill="white"/>
      </svg>
    </div>
  );
}
