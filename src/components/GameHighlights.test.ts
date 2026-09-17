import { flushPromises, shallowMount } from '@vue/test-utils'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import type { Game } from '@/types/domain'
import { fetchGameHighlights } from '@/services/dataService'
import { gameHighlights } from '@/utils/gameHighlights'
import GameHighlights from './GameHighlights.vue'

vi.mock('@/services/dataService', () => ({ fetchGameHighlights: vi.fn() }))
const game: Game = {
  id: 'game-1',
  season_id: 'season-1',
  opponent: 'Visitors',
  played_at: '2026-09-16',
  status: 'completed',
  team_score: 3,
  opponent_score: null,
  archived_at: null,
  archived_by: null,
  created_at: '',
  updated_at: '',
}
function mount(status = game.status) {
  return shallowMount(GameHighlights, {
    props: { game: { ...game, status } },
    global: {
      stubs: {
        VBtn: { template: '<button><slot /></button>' },
        VDialog: {
          props: ['modelValue'],
          template: '<div v-if="modelValue" role="dialog"><slot /></div>',
        },
        VCard: { template: '<div><slot /></div>' },
        VCardTitle: { template: '<h2><slot /></h2>' },
        VCardText: { template: '<div><slot /></div>' },
        VCardActions: { template: '<div><slot /></div>' },
      },
    },
  })
}
beforeEach(() => vi.resetAllMocks())
describe('game highlights dialog', () => {
  it('opens the top three highlights and closes them', async () => {
    vi.mocked(fetchGameHighlights).mockResolvedValue(
      gameHighlights(
        ['Alex', 'Blair', 'Casey'].map((name) => ({
          player_id: name,
          player_name: name,
          result: 'single',
          rbi: 0,
          scorers: [],
        })),
      ),
    )
    const wrapper = mount()
    await flushPromises()
    expect(wrapper.text()).toContain('MVP: Alex')
    expect(wrapper.find('[role="dialog"]').exists()).toBe(false)
    await wrapper.find('button').trigger('click')
    expect(wrapper.findAll('li')).toHaveLength(3)
    expect(wrapper.find('li').text()).toContain('1-for-1')
    await wrapper.findAll('button').at(-1)!.trigger('click')
    expect(wrapper.find('[role="dialog"]').exists()).toBe(false)
  })
  it('offers retry after an error and handles empty recorded data', async () => {
    vi.mocked(fetchGameHighlights)
      .mockRejectedValueOnce(new Error('offline'))
      .mockResolvedValueOnce([])
    const wrapper = mount()
    await flushPromises()
    expect(wrapper.text()).toContain('Highlights unavailable')
    await wrapper.find('button').trigger('click')
    await flushPromises()
    expect(wrapper.text()).toContain('No recorded highlights')
    expect(wrapper.text()).not.toContain('MVP:')
  })
  it('does not award an MVP to an unfinished game', () => {
    const wrapper = mount('in_progress')
    expect(fetchGameHighlights).not.toHaveBeenCalled()
    expect(wrapper.text()).not.toContain('MVP:')
  })
})
