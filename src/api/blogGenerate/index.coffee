SSG = require('./SiteGenerator')

config = {
  bucketName: 'www.sevenspirals.net'
  prefix: 'admin/posts/'
  suffix: '.yml'
  categoryName:
    uncategorized: '未分類'
    diary: '日記'
    tools: 'ツール'
    stationery: '文具'
    skyrim: 'Skyrim'
    programming: 'プログラミング'
}

ssg = new SSG()

exports.handler = (event, context) ->
  ssg.setup(config).index().category().calendar().articles().do((err) ->
    if err
      context.done(err)
    else
      context.succeed('scuccess.')
  )
