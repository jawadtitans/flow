import { create } from 'zustand'
import type { User } from './types'
export const useSession = create<{ token: string | null; user: User | null; status: 'loading' | 'authenticated' | 'anonymous'; setToken: (token: string) => void; setUser: (user: User) => void; clear: () => void }>(set => ({ token: null, user: null, status: 'loading', setToken: token => set({ token }), setUser: user => set({ user, status: 'authenticated' }), clear: () => set({ token: null, user: null, status: 'anonymous' }) }))
