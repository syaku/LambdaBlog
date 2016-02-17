read = require('fs').readFileSync

aws = require 'aws-sdk'
moment = require 'moment'
_ = require 'underscore'
async = require 'async'

ejs = require 'ejs'
marked = require 'marked'

s3 = new aws.S3()

_.mixin({
  chunk: (array, size) ->
    return _.chain(array).groupBy((element, index) ->
      Math.floor(index / size)
    ).toArray().value()
})

settings = {
  bucketName: 'test-lambda-backet'
  publishBucket: 'blog-public-bucket'
  postsDir: 'posts/'
  baseDir: ''
}

indexTemplate = ejs.compile(read('./template/index.ejs', 'utf8'), {filename: './template/index.ejs'})
categoryTemplate = ejs.compile(read('./template/article.ejs', 'utf8'), {filename: './template/article.ejs'})
articleTemplate = ejs.compile(read('./template/article.ejs', 'utf8'), {filename: './template/article.ejs'})

buildArticle = (pair, callback) ->
  key = pair[0]
  post = pair[1]
  s3.getObject {Bucket: settings.bucketName, Key: "#{settings.postsDir}#{key}"}, (err, data) ->
    if err
      callback(err)
    else
      publishDate = moment(post.publishDate)
      htmlBody = articleTemplate({title: post.title, body: marked(data.Body.toString('UTF-8'))})
      s3.putObject {Bucket: settings.publishBucket, Key: "#{publishDate.format('YYYY/MM/DD')}/#{key}/index.html", Body: htmlBody, ContentType: 'text/html'}, (err, data) ->
        if err
          console.log err
        callback()

buildIndex = (config, callback) ->
  chunks = _.chain(config.posts).pairs()
    .sortBy((pair)->moment(pair[0].publishDate).valueOf()*-1).chunk(10).value()
  console.log chunks
  cnt = 1
  async.each chunks,
    (chunk, callback) ->
      articles = _.chain(chunk)
        .map((pair)->{key: pair[0], title: pair[1].title, publishDate: moment(pair[1].publishDate)})
        .sortBy((article)->article.publishDate.valueOf()*-1).value()
      body = indexTemplate {title: 'SEVENSPIRALS', articles: articles}
      if cnt > 1
        filename = "index#{cnt}.html"
      else
        filename = "index.html"
      s3.putObject {Bucket: settings.publishBucket, Key: filename, Body: body, ContentType: 'text/html'}, (err, data) ->
        cnt++
        callback()
    (err)->callback null, config


exports.handler = (event, context) ->
  async.waterfall [
    (callback)->
      #サイト情報取得
      s3.getObject {Bucket: settings.bucketName, Key: 'config.json'}, (err, data) ->
        if (err)
          return context.done('no data.')
        else
          callback(null, JSON.parse data.Body.toString('UTF-8'))
    (config, callback)->
      #記事ページ生成
      pairs = _.pairs config.posts
      async.each pairs, buildArticle, (err)->callback(err, config)
    buildIndex
  ], (err)->
    context.succeed 'scuccess.'
