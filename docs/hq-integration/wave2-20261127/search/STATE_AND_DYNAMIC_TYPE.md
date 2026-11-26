# Search state and Dynamic Type corrections

## Offline discovery state

The previous ZayitSearchDataController.refresh(discover: true) set discovering without reading local readiness. Any public discovery failure then replaced state with failed/incompatible, even when a valid index remained installed. Search Data invokes that path on entry.

The candidate reads the original service's local status, and still performs normal public discovery. On discovery failure it asks the original service to validate local status again. It retains ready only when that second validation returns ready. Rechecking after the await prevents a concurrently removed or damaged package from retaining readiness. Missing and invalid packages still report failure.

The actual original refresh method, package-state enum and distribution-error type were extracted and compiled in Swift6.4.3. Controlled service outcomes reproduced baseline 6 pass / 2 fail; candidate 8 pass / 0 fail. Negative controls include missing, corrupt and concurrently removed packages. Successful update discovery and local refresh without a discovery request remain intact.

These are controller-state controls using service fixtures. They are not real network or native UI evidence. Actual offline acceptance remains open until the integrated app runs under a proved per-process or owned-Simulator network restriction.

## Dynamic Type

Native116's full audit reported a UILabel that did not support Dynamic Type; the attachment did not identify the element. Its preserved passive trace showed the main global query and history heading adapting, and a second UISearchBarTextFieldLabel with adjustsFontForContentSizeCategory=false. The book-filter navigation field is the candidate affected surface; attribution remains to be verified by the next full audit.

The candidate changes only iOSSearchFilterViewController. It follows public controller/navigation-item ownership to the native field, applies the preferred body font and opts that field's placeholder labels into Dynamic Type. It runs on appearance, after layout because SwiftUI attaches the search controller lazily, and on text-size trait changes. Unrelated toolbar labels retain their styles.

The original unfiltered accessibility audit and assertions are unchanged. Apple compilation, the full Dynamic Type audit and visible resize regression checks must run on the exact integration candidate before UI acceptance is credited.
