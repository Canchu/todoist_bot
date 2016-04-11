# todoist_bot script
# this script is referenced by @licyeus

request = require 'superagent'
_ = require 'lodash'
uuid    = require 'node-uuid'

TODOIST_TOKEN = '21999d3659763122227ab471b4511c0541b46d01'

clean_urls = (str) -> str.replace(/http[s]?:\/\/(www\.)/g, '')

call_todoist = (on_success) ->
  request.get('https://todoist.com/API/v6/sync')
    .query({ token: TODOIST_TOKEN, seq_no: 0, resource_types: JSON.stringify(['projects','items']) })
    .end (err, res) ->
      return console.log 'error!', err if err

      on_success(res)


get_items = (list_name, cb) ->
  call_todoist (res) ->
    project = _.find(res.body.Projects, (project) -> project.name.toLowerCase() == list_name)
    return cb("Unable to find project '#{list_name}'") if !project

    project_items = _.filter(res.body.Items, (item) -> item.project_id == project.id)

    heading = "List '#{project.name}' has #{project_items.length} items:\n"
    output = _.reduce(project_items, (acc, item) ->
      acc += "・#{item.date_string} #{item.content}\n"
    ,heading)
    cb(output)

add_item = (list_name, item, cb) ->
  call_todoist (res) ->
    project = _.find(res.body.Projects, (project) -> project.name == list_name)
    return cb("Unable to find project '#{list_name}'") if !project

    item = clean_urls(item)

    content = if item.split(' ')[1] == undefined then item.split(' ')[0] else item.split(' ')[1]
    date_string = if item.split(' ')[1] == undefined then '' else item.split(' ')[0]

    request.get('https://todoist.com/API/v6/sync')
      .query({ token: TODOIST_TOKEN, seq_no: 0 })
      .query({
        commands: JSON.stringify([
          {
            type: 'item_add',
            uuid: uuid.v4(),
            temp_id: uuid.v4(),
            args: {
              project_id: project.id,
              content: content,
              date_string: date_string
            }
          }
        ])
      })
      .end (err, res) ->
        return console.log 'error!', err if err
        console.log JSON.stringify(res.body, null, 4)
        cb("added '#{item}' to #{project.name} list")


module.exports = (robot) ->
  robot.hear /^@todoist list (.*)/i, (res) ->
    list_name = res.match[1]
    get_items list_name, (output) => res.send output

  robot.hear /^@todoist add (.*?) to (.*)/i, (res) ->
    item = res.match[1]
    list_name = res.match[2]
    add_item list_name, item, (output) => res.send output