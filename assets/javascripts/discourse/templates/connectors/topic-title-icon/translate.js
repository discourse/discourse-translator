export default {
  shouldRender(_, component) {
    return component.siteSettings.translator_enabled;
  },
};
