'use strict';

// The original instance is supplied only by ChavrusaVisibleSurface after its
// actual `instanceof ReaderApp` check. No original UI or method is replaced.
const targets = Object.freeze({
  library: Object.freeze({menu: 'navigation', header: 'nav.browse_the_library'}),
  topics: Object.freeze({menu: 'topic toc', header: 'topics.explore_by_topic'}),
  learningSchedules: Object.freeze({menu: 'learning schedules', header: 'learning_schedules.learning_schedules'}),
  dedication: Object.freeze({menu: 'dedication', header: 'about.app_for_ios_and_android'}),
});
// A closed set of ORIGINAL non-account/non-settings menus. Unknown or future
// flows are unavailable; this adapter never dismisses an auth/private owner.
const originalNavigationMenus = new Set([null, 'navigation', 'text toc', 'search',
  'autocomplete', 'topic toc', 'topic', 'learning schedules', 'dedication']);
const failure = code => Object.assign(new Error(code), {code});
export const SEMANTIC_TARGET_CONTRACT = 'chavrusa.original-rn-target.v1';
export const isOriginalSemanticTarget = target => typeof target === 'string'
  && Object.prototype.hasOwnProperty.call(targets, target);

function originalCanNavigate(reader) {
  const state = reader?.state;
  return state?.loaded === true && state?._completedInit === true
    && state.ReaderDisplayOptionsMenuVisible === false
    && reader?._interruptingMessageRef?.state?.modalVisible === false
    && originalNavigationMenus.has(state.menuOpen)
    && (reader?.props?.interfaceLanguage === 'english' || reader?.props?.interfaceLanguage === 'hebrew');
}

/// Prepare the one exact original method BEFORE consuming native authority.
/// The returned closure contains no wait, setter replacement or arbitrary
/// selector: each case calls one captured original arrow method only.
export function prepareOriginalSemanticTarget(reader, target) {
  if (!isOriginalSemanticTarget(target) || !originalCanNavigate(reader)) {
    throw failure('ORIGINAL_SEMANTIC_TARGET_UNAVAILABLE');
  }
  if (target === 'library') {
    const original = reader.openNav;
    if (typeof original !== 'function') { throw failure('ORIGINAL_SEMANTIC_METHOD_MISSING'); }
    return () => original();
  }
  if (target === 'topics') {
    const original = reader.openTopicToc;
    if (typeof original !== 'function') { throw failure('ORIGINAL_SEMANTIC_METHOD_MISSING'); }
    return () => original(true);
  }
  const original = reader.openMenu;
  if (typeof original !== 'function') { throw failure('ORIGINAL_SEMANTIC_METHOD_MISSING'); }
  if (target === 'learningSchedules') { return () => original('learning schedules'); }
  return () => original('dedication');
}

/// Read actual original state after a real frame. This is not a copied route
/// value. Native completion still requires the independent actual original UI.
export function observeOriginalSemanticTarget(reader, target) {
  if (!isOriginalSemanticTarget(target) || !originalCanNavigate(reader)) { return null; }
  const expected = targets[target], state = reader.state;
  if (state.menuOpen !== expected.menu) { return null; }
  if (target === 'library' && (!Array.isArray(state.navigationCategories) || state.navigationCategories.length !== 0)) { return null; }
  if (target === 'topics' && state.navigationTopic !== null) { return null; }
  return Object.freeze({originalMenu: state.menuOpen, originalHeaderKey: expected.header,
    interfaceLanguage: reader.props.interfaceLanguage, originalRootSelection: true});
}
