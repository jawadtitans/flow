import * as Primitive from '@radix-ui/react-alert-dialog'
export const AlertDialog = Primitive.Root
export const AlertDialogTitle = Primitive.Title
export const AlertDialogDescription = Primitive.Description
export const AlertDialogCancel = Primitive.Cancel
export function AlertDialogContent({ children }: { children: React.ReactNode }) { return <Primitive.Portal><Primitive.Overlay className="fixed inset-0 z-50 bg-foreground/25 backdrop-blur-[2px]"/><Primitive.Content className="fixed left-1/2 top-1/2 z-50 w-[calc(100%-2rem)] max-w-md -translate-x-1/2 -translate-y-1/2 space-y-5 rounded-xl border bg-card p-6 shadow-xl">{children}</Primitive.Content></Primitive.Portal> }
