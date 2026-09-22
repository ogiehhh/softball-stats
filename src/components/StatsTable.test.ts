import { shallowMount } from '@vue/test-utils'
import { describe, expect, it } from 'vitest'
import StatsTable from './StatsTable.vue'
import { calculateBattingLine } from '@/utils/statistics'

describe('statistics views', () => {
  it('starts simple and switches between the requested columns', async () => {
    const wrapper = shallowMount(StatsTable, {
      props: {
        rows: ['Alex', 'Blair'].map((name, index) => ({
          ...calculateBattingLine([{ result: index === 0 ? 'single' : 'home_run' }]),
          mvp_count: index + 1,
          player_id: name,
          player_name: name,
          season_id: 'season',
          season_name: 'Fall',
          league_id: 'league',
          league_name: 'League',
          league_slug: 'league',
        })),
      },
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
    expect(headers()).toEqual(['Player', 'AVG', 'OBP', 'OPS', 'RBIs', 'HRs'])
    expect(wrapper.findAll('tbody tr').map((row) => row.find('td').text())).toEqual([
      'Blair',
      'Alex',
    ])
    expect(wrapper.findAll('th')[3]?.attributes('aria-sort')).toBe('descending')
    const toggle = wrapper.findComponent({ name: 'VBtnToggle' })
    toggle.vm.$emit('update:modelValue', 'advanced')
    await wrapper.vm.$nextTick()
    expect(headers().slice(0, 5)).toEqual(['Player', 'G', 'PA', 'AB', 'R'])
    expect(headers()).not.toContain('HBP')
    expect(headers()).toContain('K%')
    expect(headers().at(-1)).toBe('MVP')
    await wrapper.findAll('th button').at(-1)!.trigger('click')
    expect(wrapper.findAll('tbody tr')[0]!.findAll('td').at(-1)!.text()).toBe('2')
    toggle.vm.$emit('update:modelValue', 'simple')
    await wrapper.vm.$nextTick()
    expect(headers()).toEqual(['Player', 'AVG', 'OBP', 'OPS', 'RBIs', 'HRs'])
  })
})
