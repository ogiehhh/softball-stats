import { ref, shallowRef } from 'vue'

export function useAsyncResource<T>() {
  const data = shallowRef<T | null>(null)
  const loading = ref(false)
  const error = ref('')

  async function load(loader: () => Promise<T>): Promise<void> {
    loading.value = true
    error.value = ''

    try {
      data.value = await loader()
    } catch (caught) {
      data.value = null
      error.value = caught instanceof Error ? caught.message : 'Something went wrong.'
    } finally {
      loading.value = false
    }
  }

  return { data, loading, error, load }
}
