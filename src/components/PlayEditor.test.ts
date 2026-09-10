import { shallowMount } from '@vue/test-utils'
import { describe, expect, it } from 'vitest'
import PlayEditor from './PlayEditor.vue'
import type { Player, RecordPlayInput } from '@/types/domain'

const player = (id: string): Player => ({
  id,
  display_name: id,
  first_name: id,
  last_name: '',
  active: true,
  created_at: '',
  updated_at: '',
})

function editor(currentOuts: number) {
  return shallowMount(PlayEditor, {
    props: {
      batter: player('Batter'),
      battingOrder: 3,
      bases: { first: 'First', second: null, third: 'Third' },
      currentOuts,
      submitting: false,
      lineup: ['First', 'Third', 'Batter'].map((id, index) => ({
        game_id: 'game',
        season_id: 'season',
        player_id: id,
        batting_order: index + 1,
        player: player(id),
      })),
    },
    global: { stubs: { VBtn: { template: '<button><slot /></button>' } } },
  })
}

describe('third-out scoring editor', () => {
  it('holds runners by default, allows explicit Run, and submits the chosen run and RBI', async () => {
    const wrapper = editor(2)
    expect(wrapper.text()).not.toMatch(/HBP|Hit by pitch/i)
    await wrapper.get('[aria-label="Groundout"]').trigger('click')
    expect(wrapper.get('[aria-label="Third to 3B"]').attributes('aria-pressed')).toBe('true')
    expect(wrapper.text()).toContain('Groundout · 0 runs · 1 out · 0 RBI')
    await wrapper.get('[aria-label="Third to Run"]').trigger('click')
    const submit = wrapper.findAll('button').find((button) => button.text() === 'Record play')!
    await submit.trigger('click')
    const input = wrapper.emitted('submit')![0]![0] as RecordPlayInput
    expect(input.rbi).toBe(1)
    expect(input.runnerOutcomes.find((outcome) => outcome.playerId === 'Third')?.endingBase).toBe(
      'home',
    )
  })

  it('clears the default run when a runner out turns a groundout into an inning-ending double play', async () => {
    const wrapper = editor(1)
    await wrapper.get('[aria-label="Groundout"]').trigger('click')
    expect(wrapper.text()).toContain('Groundout · 1 run · 1 out · 1 RBI')
    await wrapper.get('[aria-label="First to Out"]').trigger('click')
    expect(wrapper.text()).toContain('Groundout · 0 runs · 2 outs · 0 RBI')
    expect(wrapper.get('[aria-label="Third to 3B"]').attributes('aria-pressed')).toBe('true')
    await wrapper.get('[aria-label="Third to Run"]').trigger('click')
    expect(wrapper.text()).toContain('Groundout · 1 run · 2 outs · 1 RBI')
  })
})
