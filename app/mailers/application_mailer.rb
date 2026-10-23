class ApplicationMailer < ActionMailer::Base
  default from: "Christopher Quentin <hello@send.christopherquentin.com>",
          reply_to: "samuelmcmullen@gmail.com"
  layout "mailer"
end
