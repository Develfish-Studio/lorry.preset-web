--!strict

local Meta = require('@lorry.utils/lib/Meta')
local Lorry = require("@lorry.utils/lib/Lorry")
local Yaml = require("@lorry.utils/lib/Yaml")
local Usql = require('@lorry.utils-usql/lib/Usql')

export type Config = {
  project: {
    name: string,
  },
  backend: any,
  compose: any,
  migrate: any,
  ['admin-ui']: any,
  database: {
    type: 'postgres' | 'mysql',
    ['connection-string']: string,
    ['table-whitelist']: {string}?,
    ['table-blacklist']: {string}?,
  }
}

export type SetupProps = {
  config: Config,
}

local Setup = {}

export type Setup = typeof(Setup)

export type SetupImpl = Setup & SetupProps

function Setup:new(o: SetupProps): Setup
  return Meta:type(o, self, 'Setup')
end

function Setup:from_path(path: string): Setup
  local config: Config = Yaml:from_file(path)
  return Setup:new({
    config = config
  })
end

function Setup:generate()
  local this = self::SetupImpl

  local database = Usql
    :from_config 'usql-config.yaml'
    :database(this.config.database["connection-string"])
    :universal(this.config.database.type)

  local db = {
    catalogs = database:catalog_records(),
    schemas = database:schema_records(),
    tables = database:table_records(),
    entities = database:table_entities(),
  }

  Lorry:generate "@lorry.preset-web/setup" {
    target = "@root",
    variables = {
      config = this.config
    }
  }

  if this.config.backend ~= nil then
    Lorry:generate "@lorry.preset-web/setup-spring-backend" {
      target = "@root",
      variables = {
        config = this.config,
        db = db,
      }
    }
  end

  if this.config['admin-ui'] ~= nil then
    Lorry:generate "@lorry.preset-web/setup-admin-ui" {
      target = "@root",
      variables = {
        config = this.config,
        db = db,
      }
    }
  end

  if this.config.compose ~= nil then
    Lorry:generate "@lorry.preset-web/setup-compose" {
      target = "@root",
      variables = {
        config = this.config,
        db = db,
      }
    }
  end
end

return Setup
