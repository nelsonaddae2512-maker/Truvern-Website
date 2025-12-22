@echo off
cd /d C:\Users\MR.NELSON\Downloads\truvern
echo // app/vendors/page.tsx> app\vendors\page.tsx
echo export const revalidate = 0;>> app\vendors\page.tsx
echo.>> app\vendors\page.tsx
echo export default async function VendorsPage() {>> app\vendors\page.tsx
echo   return (>> app\vendors\page.tsx
echo     <main style={{padding:40}}><h1>Vendors page is alive</h1></main> >> app\vendors\page.tsx
echo   );>> app\vendors\page.tsx
echo }>> app\vendors\page.tsx
