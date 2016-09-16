# Mardown Extra Options
mdExtraOptions =
  extensions: 'all'
  table_class: 'table'
# adapted from http://stackoverflow.com/a/20957476/940030
angular.module('ui.pagedown', []).directive('pagedownEditor', [
  '$compile'
  '$timeout'
  '$window'
  '$q'
  ($compile, $timeout, $window, $q) ->
    nextId = 0
    converter = Markdown.getSanitizingConverter()
    Markdown.Extra.init converter, mdExtraOptions
    converter.hooks.chain 'preBlockGamut', (text, rbg) ->
      text.replace /^ {0,3}""" *\n((?:.*?\n)+?) {0,3}""" *$/gm, (whole, inner) ->
        '<blockquote>' + rbg(inner) + '</blockquote>\n'
    {
      restrict: 'E'
      require: 'ngModel'
      scope:
        ngModel: '='
        placeholder: '@'
        showPreview: '@'
        help: '&'
        attachFiles: '&'
        insertImage: '&'
        editorClass: '=?'
        editorRows: '@'
        previewClass: '=?'
        previewContent: '=?'
      link: (scope, element, attrs, ngModel) ->
        
        scope.changed = ->
          ngModel.$setDirty()
          scope.$parent.$eval attrs.ngChange
          return
        
        editorUniqueId = undefined
        if attrs.id == null
          editorUniqueId = nextId++
        else
          editorUniqueId = attrs.id
        # just hide the preview, we still need it for "onPreviewRefresh" hook
        previewHiddenStyle = if scope.showPreview == 'false' then 'display: none;' else ''
        placeholder = attrs.placeholder or ''
        editorRows = attrs.editorRows or '10'
        newElement = $compile('<div>' + '<div class="wmd-panel">' + '<div id="wmd-button-bar-' + editorUniqueId + '"></div>' + '<textarea id="wmd-input-' + editorUniqueId + '" placeholder="' + placeholder + '" ng-model="ngModel"' + ' ng-change="changed()"' + ' rows="' + editorRows + '" ' + (if scope.editorClass then 'ng-class="editorClass"' else 'class="wmd-input"') + '>' + '</textarea>' + '</div>' + '<div id="wmd-preview-' + editorUniqueId + '" style="' + previewHiddenStyle + '"' + ' ' + (if scope.previewClass then 'ng-class="previewClass"' else 'class="wmd-panel wmd-preview"') + '>' + '</div>' + '</div>')(scope)
        # html() doesn't work
        element.append newElement
        
        options =
          helpButton: {}
                     
        #help button
        options.helpButton.handler = if angular.isFunction(scope.help) then scope.help else (->
        # redirect to the guide by default
          $window.open 'http://daringfireball.net/projects/markdown/syntax', '_blank'
          return
        )
  
        #add attach files button only if we have a function
        if angular.isFunction(scope.attachFiles)
          options.attachFilesButton = {}
          options.attachFilesButton.handler = scope.attachFiles
#          options.attachFilesButton.handler = scope.insertImage
          options.attachFilesButton.title = "attach files"
  
          console.log "hmm"
                              
        #create editor
        editor = new (Markdown.Editor)(converter, '-' + editorUniqueId, options)
        
        editorElement = angular.element(document.getElementById('wmd-input-' + editorUniqueId))
        editorElement.val scope.ngModel
        converter.hooks.chain 'postConversion', (text) ->
          ngModel.$setViewValue editorElement.val()
          # update
          scope.previewContent = text
          text
          
        # add watch for content
        if scope.showPreview != 'false'
          scope.$watch 'content', ->
            editor.refreshPreview()
            return
        editor.hooks.chain 'onPreviewRefresh', ->
# wire up changes caused by user interaction with the pagedown controls
# and do within $apply
          $timeout ->
            scope.content = editorElement.val()
            return
          return
        if angular.isFunction(scope.insertImage)
          editor.hooks.set 'insertImageDialog', (callback) ->
# expect it to return a promise or a url string
            result = scope.insertImage()
            # Note that you cannot call the callback directly from the hook; you have to wait for the current scope to be exited.
            # https://code.google.com/p/pagedown/wiki/PageDown#insertImageDialog
            $timeout ->
              if !result
# must be null to indicate failure
                callback null
              else
# safe way to handle either string or promise
                $q.when(result).then ((imgUrl) ->
                  callback imgUrl
                  return
                ), (reason) ->
                  callback null
                  return
              return
            true
        editor.run()
        return
      
    }
]).directive 'pagedownViewer', [
  '$compile'
  '$sce'
  ($compile, $sce) ->
    converter = Markdown.getSanitizingConverter()
    Markdown.Extra.init converter, mdExtraOptions
    {
      restrict: 'E'
      scope: content: '='
      link: (scope, element, attrs) ->
        
        run = ->
          if !scope.content
            scope.sanitizedContent = ''
            return
          scope.sanitizedContent = $sce.trustAsHtml(converter.makeHtml(scope.content))
          return
        
        scope.$watch 'content', run
        run()
        newElementHtml = '<p ng-bind-html=\'sanitizedContent\'></p>'
        newElement = $compile(newElementHtml)(scope)
        element.append newElement
        return
      
    }
]

# ---
# generated by js2coffee 2.2.0