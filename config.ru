$:.unshift(__FILE__, ".")

require 'contact'

use Rack::ShowExceptions

run Sinatra::Application