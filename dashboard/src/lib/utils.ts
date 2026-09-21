import { clsx, type ClassValue } from 'clsx'
import { twMerge } from 'tailwind-merge'
export function cn(...inputs: ClassValue[]) { return twMerge(clsx(inputs)) }
export const number = (n: number) => new Intl.NumberFormat('en').format(n)
export const date = (value: string, options?: Intl.DateTimeFormatOptions) => new Intl.DateTimeFormat('en', options || { month: 'short', day: 'numeric', year: 'numeric' }).format(new Date(value))
export const initials = (name: string) => name.trim().split(/\s+/).slice(0, 2).map(part => part[0]).join('').toUpperCase()
