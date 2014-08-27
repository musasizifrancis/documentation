---
---

$ ->
  class Ui

  class Ui.Watcher
    constructor: ->
      @init()

    init: =>

      @_watchInputs $('[data-watch="input"]') if $('[data-watch="input"]').length > 0
      @_watchInputs $('[data-watch="textarea"]'), 'textarea' if $('[data-watch="textarea"]').length > 0
      @_calculateFooterHeight()
      @_setTitleImage()

    _calculateFooterHeight: ->
      targetHeight = $('.widgetArea').outerHeight()
      $('.pageContent').css('min-height',targetHeight + "px")

    _setTitleImage: ->
      $div = $('.titleImg')
      src = $div.data('bg-src')
      $div.css 'background-image', "url(#{src})"

    _watchInputs: ($elems, targetType = 'input') ->
      # Initiate: add class to every input that's not empty
      $elems.each ->
        $(this).addClass 'has-content' if $(this).find(targetType).val() != '' || $(this).find(targetType).is(":focus")

      # Handle FOCUS event
      $(targetType,'[data-watch="' + targetType + '"]').on 'focus', ->
        $(this).parent().addClass 'has-focus'

      # Handle BLUR event
      $(targetType,'[data-watch="' + targetType + '"]').on 'blur', ->
        # dynamicly set class 'has-content'
        if $(this).val().trim() != ''
          $(this).parent().addClass 'has-content'
        else
          $(this).parent().removeClass 'has-content'

        # always remove class 'has-focus' when leaving
        $(this).parent().removeClass 'has-focus'


  new Ui.Watcher
