# Canvas User Picker Sample (Outlook-style People Picker)

A Canvas-app reference implementation that mimics the **Outlook / InfoPath people picker** experience:

| Requirement                              | How it's solved here                                                                |
|------------------------------------------|-------------------------------------------------------------------------------------|
| People picker like Outlook / InfoPath    | Multi-select **ComboBox** bound to `Office365Users.SearchUser`                       |
| Resolve incorrect / unrecognised names   | On-change "resolve" check + `Notify(...)` warning when no exact match                |
| Avoid re-typing when one entry is wrong  | Selections persisted into a **collection** (`colPeople`) and rebound as the default  |
| Allow reordering (drag/drop substitute)  | Selected people rendered in a **Gallery** with ↑ / ↓ reorder buttons (Patch + Sort)  |
| True drag-drop (optional)                | Out of scope here — see `## Advanced: PCF drag-drop` below                           |

> Canvas apps do **not** support native drag/drop reorder inside a ComboBox.
> The gallery wrapper is the supported, low-code workaround. PCF is the only path to true drag/drop.

---

## Install the packaged solution (fastest path)

A ready-to-import **managed solution** is published under [`out/`](out/):

| File | Use it when... |
|------|----------------|
| [`out/CanvasUserPickerSample_managed.zip`](out/CanvasUserPickerSample_managed.zip) | You just want to **try the app** in your environment. Imports as locked/managed. |
| [`out/CanvasUserPickerSample_unmanaged.zip`](out/CanvasUserPickerSample_unmanaged.zip) | You want to **edit / extend** the app in your own solution. Imports as unmanaged. |

### Import via the maker portal
1. Go to <https://make.powerapps.com> → pick a target environment.
2. **Solutions** → **Import solution** → browse to the `.zip` → **Next** → **Import**.
3. After import completes, open the solution → run **CanvasUserPickerSample**.
4. When prompted, sign in to wire up the **Office 365 Users** connection.

### Import via Power Platform CLI
```powershell
# Authenticate against the target env (one-time)
pac auth create --environment <env-id-or-url>

# Import the managed solution and publish
pac solution import `
  --path .\out\CanvasUserPickerSample_managed.zip `
  --publish-changes
```

Verify with `pac solution list` — you should see `CanvasUserPickerSample` (publisher prefix `sns`).

> Want to repack from source? See [Layout](#layout) and `pack.ps1`. The exports in `out/` are produced from the **SeaCass** environment via `pac solution export`.

---

## Layout

```
CanvasUserPickerSample/
├── README.md                          ← this file
├── pack.ps1                           ← convenience wrapper around `pac canvas pack`
└── Src/
    ├── App.fx.yaml                    ← OnStart: seed colPeople
    └── Screens/
        └── PeoplePickerScreen.fx.yaml ← ComboBox + Gallery + reorder buttons
```

The `Src/` folder follows the **Power Platform CLI canvas source** layout (`pac canvas pack`).
The YAML is annotated and easy to copy into Power Apps Studio directly if you'd rather
build the screen by hand.

---

## Quick start — option A: copy formulas into Power Apps Studio

1. Open <https://make.powerapps.com> → **+ Create** → **Blank canvas app** (Tablet).
2. Add the **Office 365 Users** connector (left rail → Data → + Add data).
3. Add a **ComboBox** named `cmbPeoplePicker` and set the properties below.
4. Add a **vertical Gallery** named `galSelected` and set the properties below.
5. Inside the gallery template add three controls: `lblName`, `btnUp`, `btnDown`, `btnRemove`.
6. Optionally add `btnSubmit` to show downstream usage.

### `App.OnStart`
```powerfx
// Seed an empty, shape-typed collection so the gallery + combo bind cleanly on first load.
ClearCollect(
    colPeople,
    {
        Order:        0,
        DisplayName:  "",
        Mail:         "",
        JobTitle:     "",
        UserPrincipalName: ""
    }
);
Clear(colPeople);
```

### `cmbPeoplePicker` (ComboBox)
| Property             | Value |
|----------------------|-------|
| `Items`              | `Office365Users.SearchUser({searchTerm: Self.SearchText})` |
| `SelectMultiple`     | `true` |
| `IsSearchable`       | `true` |
| `SearchFields`       | `["DisplayName","Mail"]` |
| `DisplayFields`      | `["DisplayName","Mail"]` |
| `DefaultSelectedItems` | `colPeople` |
| `OnChange`           | see below |

#### `cmbPeoplePicker.OnChange` — persist selections + resolve unknown text
```powerfx
// 1) Persist every selected user into colPeople, preserving any existing Order value.
ClearCollect(
    colPeople,
    ForAll(
        Self.SelectedItems As _sel,
        {
            Order:             CountRows(Filter(colPeople, Mail = _sel.Mail)) + 0
                                + If(IsBlank(LookUp(colPeople, Mail = _sel.Mail)),
                                     CountRows(colPeople) + 1,
                                     LookUp(colPeople, Mail = _sel.Mail).Order),
            DisplayName:       _sel.DisplayName,
            Mail:              _sel.Mail,
            JobTitle:          _sel.JobTitle,
            UserPrincipalName: _sel.UserPrincipalName
        }
    )
);

// 2) Outlook-style "resolve names" — warn when the typed text didn't match a user.
If(
    !IsBlank(Self.SearchText)
        && IsEmpty(
            Filter(
                Office365Users.SearchUser({searchTerm: Self.SearchText}),
                Lower(DisplayName) = Lower(Self.SearchText)
                    || Lower(Mail) = Lower(Self.SearchText)
            )
        ),
    Notify(
        "We couldn't resolve """ & Self.SearchText & """. Pick a suggestion from the list.",
        NotificationType.Warning,
        4000
    )
);
```

### `galSelected` (Gallery — vertical)
| Property  | Value |
|-----------|-------|
| `Items`   | `Sort(colPeople, Order, SortOrder.Ascending)` |
| `Layout`  | Title (or blank — we author the row by hand) |

Inside the gallery template:

#### `lblName.Text`
```powerfx
ThisItem.DisplayName & "  •  " & ThisItem.Mail
```

#### `btnUp.OnSelect` — move row up one slot
```powerfx
With(
    {
        _curr: ThisItem,
        _prev: First(
            Sort(
                Filter(colPeople, Order < ThisItem.Order),
                Order,
                SortOrder.Descending
            )
        )
    },
    If(
        !IsBlank(_prev),
        Patch(colPeople, _curr, {Order: _prev.Order});
        Patch(colPeople, _prev, {Order: _curr.Order})
    )
)
```

#### `btnDown.OnSelect` — move row down one slot
```powerfx
With(
    {
        _curr: ThisItem,
        _next: First(
            Sort(
                Filter(colPeople, Order > ThisItem.Order),
                Order,
                SortOrder.Ascending
            )
        )
    },
    If(
        !IsBlank(_next),
        Patch(colPeople, _curr, {Order: _next.Order});
        Patch(colPeople, _next, {Order: _curr.Order})
    )
)
```

#### `btnRemove.OnSelect` — drop a person without retyping the rest
```powerfx
Remove(colPeople, ThisItem);
// Re-pack Order so the next ↑/↓ click stays contiguous.
ClearCollect(
    colPeople,
    ForAll(
        Sort(colPeople, Order, SortOrder.Ascending) As _row,
        Patch(_row, {Order: CountRows(Filter(colPeople, Order < _row.Order)) + 1})
    )
)
```

#### Optional `btnSubmit.OnSelect` — what you actually do with the list
```powerfx
// Example: hand the ordered list off to a flow / Dataverse patch / email.
Set(
    gblRecipientsCsv,
    Concat(Sort(colPeople, Order), Mail, ";")
);
Notify("Recipients (in order): " & gblRecipientsCsv, NotificationType.Success);
```

---

## Quick start — option B: pack the included source into a `.msapp`

> Requires Power Platform CLI 1.27+ (`pac install latest`).

```powershell
# from the folder that contains pack.ps1
.\pack.ps1
```

This produces `out/CanvasUserPickerSample.msapp`. Then in <https://make.powerapps.com>:

1. **Apps → Import canvas app → Upload** the `.msapp`, OR
2. Open an existing app → **File → Open → Browse** and pick the `.msapp`.

---

## Why this pattern (vs. the obvious alternatives)

| You might be tempted to…                             | Why this sample does it differently                              |
|------------------------------------------------------|------------------------------------------------------------------|
| Bind `cmbPeoplePicker.DefaultSelectedItems` directly to `Self.SelectedItems` | Won't survive an error/fix loop — fixing one bad entry forces the user to re-pick everyone. The collection breaks that coupling. |
| Use `OnSelect` instead of `OnChange` for persistence | `OnSelect` fires on the chevron click, not on every multi-select change. `OnChange` matches real selection events. |
| Skip the `Order` column and rely on collection order | `Patch` / `Remove` shuffle physical order non-deterministically; an explicit `Order` integer is the only reliable way to drive the ↑/↓ buttons. |
| Filter `SearchUser` results in PowerFx               | `SearchUser` already does Graph-side fuzzy match. Re-filtering client-side only hides matches; trust the connector and surface "no match" as a warning. |

---

## Advanced: true drag-drop reorder

Out of scope for low-code Canvas. Two routes if the customer insists:

1. **PCF control** — write a custom PCF wrapping `@fluentui/react` `PeoplePicker` or
   a `react-beautiful-dnd` list. Ships as a solution component, drops into the
   Canvas screen like any other control.
2. **Embedded Power Apps Component Framework + Office UI Fabric** — same idea, but
   leverages the Fluent UI `NormalPeoplePicker` for the suggestion list and a
   `Stack` + drag handles for ordering.

Both lose the "no-code" property but give you the exact Outlook UX.

---

## Connectors required

- **Office 365 Users** (`Office365Users.SearchUser`, `Office365Users.UserPhoto` if you add an avatar)

Add it via **Data → Add data → Office 365 Users** in Power Apps Studio, or it will be
auto-bound on import when the `.msapp` is uploaded into an environment that already
has the connector enabled.
