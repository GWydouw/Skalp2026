# p027readwrite.rb
# Open and read from a text file
# Note that since a block is given, file will
# automatically be closed when the block terminates

filepath = File.dirname(__FILE__)
require filepath + '/encryptor.rb'
require 'ruby_parser'
require 'ruby_to_ruby_c'

a = ""
File.open('macaddr.rb', 'r') do |f1|

  while line = f1.gets
    a += line
  end

  sexp = RubyParser.new.parse a

  puts sexp
  c = RubyToAnsiC.new.process sexp

  salt = Time.now.to_i.to_s
  secret_key = 'secret'
  iv = OpenSSL::Cipher::Cipher.new('aes-256-cbc').random_iv

  a.encrypt!(:key => secret_key, :iv => iv, :salt => salt)

  puts a

  eval(a.decrypt(:key => secret_key, :iv => iv, :salt => salt))

  puts c

end








