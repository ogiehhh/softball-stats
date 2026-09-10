import { shallowMount } from '@vue/test-utils'
import { describe, expect, it } from 'vitest'
import StatsTable from './StatsTable.vue'

describe('statistics views', () => {
  it('starts simple and switches between the requested columns', async () => {
    const wrapper = shallowMount(StatsTable, {
      props: { rows: [] },
      global: {
        stubs: {
          VTable: { template: '<table><slot /></table>' },
          VBtnToggle: { name: 'VBtnToggle', template: '<div><slot /></div>' },
          RouterLink: true,
          VBtn: { template: '<button><slot /></button>' },
        },
      },
    })
    const headers = () => wrapper.findAll('th').map((header) => header.text())
    expect(headers()).toEqual(['Player', 'AVG', 'OBP', 'RBIs', 'HRs'])
    const toggle = wrapper.findComponent({ name: 'VBtnToggle' })
    toggle.vm.$emit('update:modelValue', 'advanced')
    await wrapper.vm.$nextTick()
    expect(headers().slice(0, 4)).toEqual(['Player', 'AVG', 'SLG', 'OBP'])
    expect(headers()).toContain('OPS')
    expect(headers()).not.toContain('HBP')
    toggle.vm.$emit('update:modelValue', 'simple')
    await wrapper.vm.$nextTick()
    expect(headers()).toEqual(['Player', 'AVG', 'OBP', 'RBIs', 'HRs'])
  })
})
