/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_API_CATALOG_URL: string
  readonly VITE_API_CART_URL: string
  readonly VITE_API_CHECKOUT_URL: string
  readonly VITE_API_FEATURE_FLAG_URL: string
  readonly VITE_OTEL_COLLECTOR_URL: string
}

interface ImportMeta {
  readonly env: ImportMetaEnv
}
