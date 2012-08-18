# See blog post at http://vitobotta.com/sinatra-contact-form-jekyll/

%w(rubygems sinatra liquid resolv open-uri haml pony).each{ |g| require g }
configure :production do
  require 'newrelic_rpm'
end

set :protection, :except => :frame_options


not_found do
  status 404
  not_found_template = File.join(APP_ROOT, "public", "404.html")
  File.exists?(not_found_template) ? File.read(not_found_template) : "Oops, the page you are looking for does not exist :("
end

def valid_email?(email)
  if email =~ /^[a-zA-Z][\w\.-]*[a-zA-Z0-9]@[a-zA-Z0-9][\w\.-]*[a-zA-Z0-9]\.[a-zA-Z][a-zA-Z\.]*[a-zA-Z]$/
    domain = email.match(/\@(.+)/)[1]
    Resolv::DNS.open do |dns|
        @mx = dns.getresources(domain, Resolv::DNS::Resource::IN::MX)
    end
    @mx.size > 0 ? true : false
  else
    false
  end
end

def given? field
  !field.empty?
end

def validate params
  errors = {}

  [:name, :email, :message].each{|key| params[key] = (params[key] || "").strip }

  errors[:name]    = "This field is required" unless given? params[:name]

  if given? params[:email]
    errors[:email]   = "Please enter a valid email address" unless valid_email? params[:email]
  else
    errors[:email]   = "This field is required"
  end

  errors[:message] = "This field is required" unless given? params[:message]
  
  if given? params[:im_a_robot]
    errors[:im_a_robot] = "Only robots fill in this field. I don't want email from robots."
  end


  errors
end

def send_email params, ip_address
  email_template = <<-EOS



  Sent via http://www.travisberry.com/contact/ 
  When:          {{ when }}  
  IP address:    {{ ip_address }}

  Your name:     {{ name }}
  Email:         {{ email }}

  Message:       

  {{ message }}

  EOS

  body = Liquid::Template.parse(email_template).render  "name"       => params[:name], 
                                                        "email"      => params[:email], 
                                                        "website"    => params[:website], 
                                                        "message"    => params[:message], 
                                                        "when"       => Time.now.strftime("%b %e, %Y %H:%M:%S %Z"), 
                                                        "ip_address" => ip_address

  Pony.options = {
    :via => :smtp,
    :via_options => {
      :address => 'smtp.sendgrid.net',
      :port => '587',
      :domain => 'heroku.com',
      :user_name => ENV['SENDGRID_USERNAME'],
      :password => ENV['SENDGRID_PASSWORD'],
      :authentication => :plain,
      :enable_starttls_auto => true
    }
  }

  Pony.mail(:to => "contact@travisberry.com", :from => params[:email], :subject => "A comment from #{params[:name]}", :body => body)
end


get '/contact-form/?' do
  @errors, @values, @sent = {}, {}, false
  haml :contact_form
end

post '/contact-form/?' do
  @errors     = validate(params)
  @values     = params

  if @errors.empty?
    begin
      send_email(params, @env['REMOTE_ADDR']) 
      @sent = true
  
    rescue Exception => e
      puts e
      @failure = "Ooops, it looks like something went wrong while attempting to send your email. Mind trying again now or later? :)"
    end
  end

  haml :contact_form
end

