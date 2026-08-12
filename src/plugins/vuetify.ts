import { createVuetify } from 'vuetify'

export const vuetify = createVuetify({
  theme: {
    defaultTheme: 'softballNight',
    themes: {
      softballNight: {
        dark: true,
        colors: {
          background: '#101416',
          surface: '#171d20',
          'surface-bright': '#283136',
          'surface-variant': '#222a2e',
          'on-background': '#edf2f3',
          'on-surface': '#edf2f3',
          'on-surface-variant': '#d7e0e3',
          primary: '#f0a064',
          'on-primary': '#211207',
          'primary-darken-1': '#d9874d',
          secondary: '#83b7c9',
          'on-secondary': '#071519',
          accent: '#e1bb71',
          success: '#72c994',
          'on-success': '#07170e',
          info: '#7cc3e1',
          'on-info': '#06161d',
          warning: '#f1bf6a',
          'on-warning': '#1c1203',
          error: '#ff817b',
          'on-error': '#250604',
        },
      },
    },
  },
  defaults: {
    VBtn: {
      rounded: 'md',
      elevation: 0,
      style: 'font-weight: 750;',
    },
    VCard: {
      rounded: 'lg',
      elevation: 0,
    },
    VTextField: {
      variant: 'outlined',
      density: 'comfortable',
      hideDetails: 'auto',
    },
  },
})
