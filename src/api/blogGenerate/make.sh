npm install
coffee -cb index.coffee
coffee -cb SiteGenerator.coffee
zip -r blogGenerate.zip index.js SiteGenerator.js node_modules template

