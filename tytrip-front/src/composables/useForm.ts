import { reactive, ref } from 'vue'
import { ElMessage } from 'element-plus'
import { ApiError } from '@/api/client'

/**
 * Submission state for a form: loading flag, server validation errors per
 * field (shown next to inputs) and a general error message.
 */
export function useForm() {
  const submitting = ref(false)
  const fieldErrors = reactive<Record<string, string>>({})
  const error = ref<string | null>(null)

  function reset() {
    Object.keys(fieldErrors).forEach((key) => delete fieldErrors[key])
    error.value = null
  }

  async function submit<T>(action: () => Promise<T>, successMessage?: string): Promise<T | undefined> {
    reset()
    submitting.value = true
    try {
      const result = await action()
      if (successMessage) ElMessage.success(successMessage)
      return result
    } catch (err) {
      if (err instanceof ApiError) {
        for (const [field, messages] of Object.entries(err.details)) fieldErrors[field] = messages[0] ?? ''
        error.value = err.isValidation ? (fieldErrors.base ?? 'Veuillez corriger les champs en erreur.') : err.message
      } else {
        error.value = 'Une erreur inattendue est survenue.'
        console.error(err)
      }
      return undefined
    } finally {
      submitting.value = false
    }
  }

  return { submitting, fieldErrors, error, submit, reset }
}

/** Runs a loader with a loading flag and an error message. */
export function useLoader() {
  const loading = ref(false)
  const error = ref<string | null>(null)

  async function load<T>(loader: () => Promise<T>): Promise<T | undefined> {
    loading.value = true
    error.value = null
    try {
      return await loader()
    } catch (err) {
      error.value = err instanceof ApiError ? err.message : 'Une erreur inattendue est survenue.'
      return undefined
    } finally {
      loading.value = false
    }
  }

  return { loading, error, load }
}
