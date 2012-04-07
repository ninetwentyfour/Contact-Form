$:.unshift(__FILE__, ".")

require 'contact_form'

use Rack::ShowExceptions

run ContactForm.new