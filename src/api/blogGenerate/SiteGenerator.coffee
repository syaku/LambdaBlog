read = require('fs').readFileSync
moment = require('moment')
_ = require('underscore')
async = require('async')
yaml = require('js-yaml')
ejs = require('ejs')
marked = require('marked')
aws = require('aws-sdk')
s3 = new aws.S3()

_.mixin({
  chunk: (array, size) ->
    return _.chain(array).groupBy((element, index) ->
      Math.floor(index / size)
    ).toArray().value()
})

baseParam = {
  Bucket: ''
}

indexTemplate = ejs.compile(read('./template/index.ejs', 'utf8'), {filename: './template/index.ejs'})
categoryTemplate = ejs.compile(read('./template/article.ejs', 'utf8'), {filename: './template/article.ejs'})
articleTemplate = ejs.compile(read('./template/article.ejs', 'utf8'), {filename: './template/article.ejs'})

class SiteGenerator
  setup: (settings) ->
    @settings = settings
    baseParam.Bucket = @settings.bucketName
    @chain = []
    @config = {}
    @chain.push((callback) =>
      console.log("setup.")
      #サイト情報取得
      param = _.extend(
        {Key: 'admin/config.json'}
        baseParam
      )
      s3.getObject(param, (err, data) =>
        if err
          callback(err)
        else
          @config = JSON.parse data.Body.toString('UTF-8')
          @categories = _.chain(@config.category).keys().sortBy((category)->category).value()
          @calendar = _.chain(@config.calendar).keys().sortBy((month)->month).value().reverse()
          callback()
      )
    )
    return this

  index: ->
    @chain.push((callback) =>
      console.log('index.')
      pages = _.chain(@config.posts).map((post, key) -> _.extend(post, {key: key}))
        .sortBy((post) -> moment(post.timestamp).valueOf()*-1).chunk(10).value()
      @_indexPage(null, '', pages, callback)
    )
    return this

  calendar: ->
    @chain.push((callback) =>
      console.log('calendar.')
      async.forEachOf(@config.calendar
        (posts, calendar, callback) =>
          pages = _.chain(posts).sortBy((post) -> moment(post.timestamp).valueOf()*-1).chunk(10).value()
          @_indexPage("#{moment(calendar).format('YYYY年MM月')}", "#{calendar}/", pages, callback)
        (err)->callback(err)
      )
    )
    return this

  category: ->
    @chain.push((callback) =>
      console.log('category.')
      async.forEachOf(@config.category
        (posts, category, callback) =>
          pages = _.chain(posts).sortBy((post) -> moment(post.timestamp).valueOf()*-1).chunk(10).value()
          @_indexPage("#{@settings.categoryName[category]}", "archive/category/#{category}/", pages, callback)
        (err)->callback(err)
      )
    )
    return this

  articles: ->
    #記事ページ生成
    @chain.push((callback) =>
      console.log('articles.')
      async.each(
        _.keys(@config.posts)
        (key, callback) =>
          param = _.extend(
            {Key: "#{@settings.prefix}#{key}#{@settings.suffix}"}
            baseParam
          )
          s3.getObject(param, (err, data) =>
            if err
              callback(err)
            else
              post = yaml.safeLoad(data.Body.toString('UTF-8'))
              post.timestamp = moment(post.timestamp)
              post.body = marked(post.body)
              path = "#{post.timestamp.format('YYYY/MM/DD')}/#{key}/index.html"
              post.category = if post.category then post.category else 'uncategorized'
              html = articleTemplate(_.extend({
                url: "#{post.timestamp.format('YYYY/MM/DD')}/#{key}/"
                thumbnail: if post.thumbnail then post.thumbnail else null
                key: key
                categories: @categories
                calendar: @calendar
                settings: @settings
                moment: moment
              }, post))
              param = _.extend(
                {Key: path, Body: html, ContentType: 'text/html', CacheControl: 'max-age=86400, s-maxage=300, no-transform, public'}
                baseParam
              )
              s3.putObject(param, (err, data) ->
                if err
                  callback(err)
                else
                  callback()
              )
          )
        (err)->callback(err)
      )
    )
    return this

  do: (callback)->
    async.series(@chain, (err, result) -> callback(err))

  _indexPage: (title, prefix, pages, callback) ->
    cnt = 1
    async.eachSeries(pages,
      (articles, callback) =>
        articles = _.map(articles, (article) =>
          article.timestamp = moment(article.timestamp)
          return article
        )
        path = "#{prefix}index#{if cnt > 1 then cnt else ''}.html"
        html = indexTemplate({
          url: "#{prefix}#{if cnt == 1 then '' else "index#{cnt}.html"}"
          thumbnail: null
          title: title
          currentPage: cnt
          maxPage: pages.length
          articles: articles
          prefix: prefix
          categories: @categories
          calendar: @calendar
          settings: @settings
          moment: moment
        })
        param = _.extend(
          {Key: path, Body: html, ContentType: 'text/html', CacheControl: 'max-age=86400, s-maxage=300, no-transform, public'}
          baseParam
        )
        s3.putObject(param, (err, data) ->
          cnt++
          callback()
        )
      (err)->callback(err)
    )

module.exports = SiteGenerator
