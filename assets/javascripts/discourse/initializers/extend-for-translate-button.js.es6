import PostMenuComponent from 'discourse/components/post-menu';
import { Button } from 'discourse/components/post-menu';
import computed from 'ember-addons/ember-computed-decorators';
import { popupAjaxError } from 'discourse/lib/ajax-error';

export default {
  name: 'extend-for-translate-button',
  initialize: function() {
    PostMenuComponent.registerButton(function(visibleButtons){
      var position = 0;
      visibleButtons.splice(position, 0, new Button('translate', 'translator.view_translation', 'globe'))
    });

    PostMenuComponent.reopen({
      clickTranslate: function(post) {
        const self = this;

        Discourse.ajax('/translator/translate', {
          type: 'POST',
          data: { post_id: post.get('id') }
        }).then(function(res) {
          const cooked = post.get('cooked');
          $('#post-cloak-' + post.get('post_number') + ' .cooked').append(
            "<hr>" + I18n.t('translator.translated_from', { language: 'Some Language', translator: self.siteSettings.translator }) + res.translation
          )
        }).catch(popupAjaxError);
      }
    });
  }
};
