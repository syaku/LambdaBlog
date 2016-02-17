aws = require 'aws-sdk'

s3 = new aws.S3()

settings = {
  bucketName: 'test-lambda-backet'
  postsDir: 'posts/'
}

exports.handler = (event, context) ->
  #サイト情報取得
  s3.getObject {Bucket: settings.bucketName, Key: 'config.json'}, (err, data) ->
    if (err)
      config = {posts:{}}
    else
      config = JSON.parse data.Body.toString('UTF-8')
    #投稿ファイル作成
    s3.putObject {Bucket: settings.bucketName, Key: "#{settings.postsDir}#{event.postName}", Body: event.body}, (err, data) ->
      if (err)
        return context.done(err)
      post = {title: event.title, publishDate: new Date(event.publishDate), category: event.category}
      config.posts[event.postName] = post
      #サイト情報更新
      s3.putObject {Bucket: settings.bucketName, Key: 'config.json', Body: JSON.stringify(config)}, (err, data) ->
        if (err)
          return context.done(err)
        else
          return context.succeed(event.body)
