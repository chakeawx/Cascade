# Fork

This fork is Cascade with a few fixes on top.

Base: `v1.4.0`

`main` is the upstream release named in Base, then one commit per fix. Each commit message says what was wrong and
how it is fixed; `git log v1.4.0..main` shows them. `patched/<version>` tags keep the last `main` of each base, so
projects pinned to an older commit still find it.

Keep each fix small and about one cause, explain the problem in its message, and do not reformat upstream files.
New behavior belongs in the code that uses Cascade, not here.

## Fixes

One section per commit, oldest first. `git show <hash>` shows the change. The hashes change on every rebase, so update
them afterwards from `git log --oneline <base>..main`.

### `22fc0b5` form: place dividers between visible rows

Files: `src/components/Form.luau`

Problem: A row showed its divider only when the next row was visible, so a hidden row between two visible rows removed
the divider between them.

Fix: Walk the rows from the end and show a row's divider when it is visible and any visible row follows it.

### `c7a5ec2` stepper: commit valid input on every focus loss

Files: `src/components/Stepper.luau`

Problem: A fielded Stepper committed typed text only on Enter. Clicking away left the typed text on screen without
changing Value, and invalid input was restored without the Step formatting.

Fix: Commit a valid number through Value on any focus loss, and restore the formatted Value otherwise.

### `0c24a77` window: keep text scale stable while minimizing

Files: `src/components/Window.luau`

Problem: Minimizing tweened the Window's UIScale to 0 while it moved offscreen, so text changed layout during the
animation.

Fix: Keep Scale at 1. Moving offscreen already hides the Window.

### `878e586` search: match queries literally

Files: `src/components/Window.luau`

Problem: Search passed the query to string.find as a Lua pattern. Queries with "[", "%" or "(" raised malformed-pattern
errors, and "." matched rows that do not contain a dot.

Fix: Search with plain matching.

### `bf143f9` window: release drag listeners on destruction

Files: `src/components/Window.luau`

Problem: The Window's global InputChanged listener and the current input's Changed listener stayed connected after the
Window was destroyed, so moving the mouse after a press still moved the destroyed Body.

Fix: Disconnect both when Body is destroyed and clear the drag state.

### `172d1be` components: remove destroyed roots from the registry

Files: `src/components/init.luau`

Problem: Destroyed component roots stayed in the component registry forever: 20 short-lived Row/Label pairs left 40 dead
entries.

Fix: Remember the registry at insertion and remove the entry when the root is destroyed, keeping the array dense and in
order. A detached page that is still alive stays registered.

### `9b2b8bb` creator: release dynamic subscriptions on destruction

Files: `src/modules/creator.luau`, `src/types.luau`

Problem: Dynamic properties subscribed to values with no way to unsubscribe, so a destroyed instance kept its callbacks
and still ran them on the next value change.

Fix: Add an optional Disconnect(callback) to value states. Keep registrations in order, duplicates included, and notify
from a snapshot. Creator.Create disconnects an instance's bindings when it is destroyed and ignores deferred updates
after that. Values without Disconnect are still accepted.

### `a9469e0` window: preserve position across minimize reversals

Files: `src/components/Window.luau`

Problem: Minimizing and restoring quickly started overlapping tweens, and a stale completion overwrote the restore
position. Six quick pairs left the Window about 328 pixels below where it started.

Fix: Keep one current tween, cancel it when replaced or when the Window is destroyed, ignore stale completions, and keep
one restore position.

### `455e5e4` text-field: preserve existing text on focus

Files: `src/structures/TextField.luau`

Problem: The shared TextField structure kept the TextBox default ClearTextOnFocus = true, so focusing search or a
fielded Stepper erased its text.

Fix: Set ClearTextOnFocus to false.

### `ec524d9` search: scope visibility snapshots to active sessions

Files: `src/components/Window.luau`

Problem: Search kept its visibility snapshot across queries and pages. Clearing a query or switching pages could restore
stale visibility, and a matching row under a hidden ancestor was shown.

Fix: One active search owns the snapshot. Clearing the query or switching pages restores and releases it, destroying the
page releases it, and matches under a hidden ancestor stay hidden. Setting Visible on a row while a search is active is
still overwritten when the search clears.

### `4932ada` blur: dispose owned connections and effects

Files: `src/modules/effects/blur.luau`

Problem: The blur model's frame, camera and workspace listeners stayed connected after it was destroyed, and each blur
toggle left a DepthOfFieldEffect behind.

Fix: Disconnect them on destruction, destroy the effect once, and ignore queued work afterwards. The folder is destroyed
after its part finishes destroying, because destroying it from the part's Destroying handler errors.

### `f637141` blur: rebind rendering when the camera changes

Files: `src/modules/effects/blur.luau`

Problem: Blur stayed bound to the camera that existed when it was created, so replacing workspace.CurrentCamera or
resizing the viewport drew it in the wrong place.

Fix: Rebind the camera listeners when CurrentCamera changes and recompute the bounds when the viewport changes.

### `ba426eb` window: restore blur for initially minimized windows

Files: `src/components/Window.luau`

Problem: A Window created minimized never built its blur, so restoring it showed none.

Fix: Create the blur while minimized and set its visibility from the current state.

### `dad2f4d` section: size expanded groups from committed layout

Files: `src/components/Section.luau`

Problem: An expanded Section watched each child's size, so removing or hiding a tab kept the old height: going from
three tabs to two stayed at 107 pixels instead of 79.

Fix: Size the Section from its layout's AbsoluteContentSize while expanded.

### `a971b19` keybindfield: disconnect input listeners on destroy

Files: `src/components/KeybindField.luau`

Problem: KeybindField connected to UserInputService.InputBegan and InputEnded and never disconnected. After its row was
destroyed, pressing the key still called the press and release callbacks.

Fix: Disconnect both when Body is destroyed.

### `517908b` radiobuttongroup: rebuild every option when Options changes

Files: `src/components/RadioButtonGroup.luau`

Problem: Setting Options destroyed only the buttons at indexes the new list reused, so going from four options to one
left three stale buttons.

Fix: Destroy every old button, build the new list, then repaint the selection without firing ValueChanged.

### `d9c7742` notification: leave the list when the body is destroyed

Files: `src/components/Notification/init.luau`

Problem: A notification left the global list only when its close animation finished. Destroying it any other way, such
as with its app, left it in the list with its expiry timer still running.

Fix: Leave the list and cancel the expiry when Body is destroyed.

## Known problems, not fixed

- Search: setting `Visible` on a row while a search is active is overwritten when the search clears. Clear the query
  first.
- Row: on a narrow Window (about 350 pixels) the right accessory and its text overflow the row. Bounding the container
  alone does not fix it; Row has to own both width budgets and stack the accessories when they cannot fit.

## Moving to a new upstream release

Once per clone, let Git remember how conflicts were resolved:

```sh
git config rerere.enabled true
```

Then, with `v1.5.0` as the new release:

```sh
git fetch upstream --tags
git tag patched/v1.4.0 main
git push origin patched/v1.4.0
git rebase --onto v1.5.0 v1.4.0 main
```

The rebase replays one fix at a time. When upstream already fixed the problem a commit describes, `git rebase --skip`
drops it; remove its section above. When done, change Base, update the hashes under Fixes, check the fixes
again in Studio, and push:

```sh
git push --force-with-lease origin main
```

Then move each project that uses the fork to the new commit.
