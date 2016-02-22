aws = require('aws-sdk')
async = require('async')
yaml = require('js-yaml')
moment = require('moment')
_ = require('underscore')

s3 = new aws.S3()

settings = {
  bucketName: 'www.sevenspirals.net'
  prefix: 'admin/posts/'
  suffix: '.yml'
}

exports.handler = (event, context) ->
  #サイト情報取得
  s3.getObject {Bucket: settings.bucketName, Key: 'admin/config.json'}, (err, data) ->
    if (err)
      config = {posts:{}}
    else
      config = JSON.parse data.Body.toString('UTF-8')
    #投稿ファイル作成
    s3.listObjects {Bucket: settings.bucketName, Prefix: settings.prefix, Delimiter: '/'}, (err, data) ->
      async.each data.Contents,
        (data, callback)->
          if data.Size == 0
            return callback()
          key = data.Key
          s3.getObject {Bucket: settings.bucketName, Key: key}, (err, data)->
            post = yaml.safeLoad(data.Body.toString('UTF-8'))
            delete post.body
            key = key.replace(settings.prefix, '').replace(settings.suffix, '')
            config.posts[key] = post
            callback()
        (err)->
          config.category = _.chain(config.posts).each((post, key)->_.extend(post, {key: key})).groupBy((post)->if post.category then post.category else 'uncategorized').value()
          config.calendar = _.chain(config.posts).each((post, key)->_.extend(post, {key: key})).groupBy((post)->moment(post.timestamp).format('YYYY/MM')).value()
          s3.putObject {Bucket: settings.bucketName, Key: 'admin/config.json', Body: JSON.stringify(config)}, (err, data)->
            if err
              context.done(err)
            else
              context.succeed('done.')
