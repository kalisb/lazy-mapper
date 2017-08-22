require 'pathname'
require Pathname(__FILE__).dirname.expand_path.parent + 'lib/lazy_mapper'

# Да се поддържа работа с поне 2 релационни бази от данни по
# ваш избор - например SQLite и PostgreSQL. Можете да използвате
# gem-ове като sqlite3 за комуникация със съответната база от данни.
# Нямате право да използвате наготово ORM библиотеки.
LazyMapper.setup(:default,  'sqlite3:test.db')
#LazyMapper.setup(:default, 'postgres://postgres:test@localhost/postgres')
@adapter = repository(:default).adapter

# Възможност за логване на направените към базата
# от данни заявки. Този лог трябва да е конфигурируем по следния начин:
# Дали да логва на стандартния изход или във файл.
# Лог записи на различни нива - DEBUG, INFO, ERROR.
# Минимално ниво на лог записите, които да се виждат в лога.
LazyMapper::Logger.new($stdout, :info)

class Article < LazyMapper::Model
  property :id, Integer, serial: true
  property :title, String
  property :body,  String
end

class Author < LazyMapper::Model
  property :id, Integer, serial: true
  property :name, String
  has n, :articles
end

# Искаме да можем да свържем произволен написан от нас клас
# с таблица в база от данни, съдържаща колони за атрибутите
# на класа. Всеки такъв клас се нарича модел.
puts '-----------------------------------------------------'
Author.create_table(:default)
Article.create_table(:default)
puts "Created table article: " + @adapter.storage_exists?("articles").to_s
puts "Created table author: " + @adapter.storage_exists?("authors").to_s
puts '-----------------------------------------------------'

# Създаване, четене, изтриване и ъпдейт (CRUD)
puts '-----------------------------------------------------'
article = Article.new(title: 'First Article', body: 'Article text')
puts 'Articles count: ' + Article.count().to_s
article.save
puts 'Articles count: ' + Article.count().to_s
puts 'Article title: ' + article.title
puts 'Article body: ' + article.body
article.title = "Second Article"
article.update
puts 'Updated title: ' + article.title
puts 'Articles count: ' + Article.count().to_s
article.destroy
puts 'Articles count: ' + Article.count().to_s
puts '-----------------------------------------------------'

# Сортиране по произволни атрибути и в произволна посока (ascending/descending)
puts '-----------------------------------------------------'
5.times do |time|
    Article.new(title: 'Firsrt Article'  + time.to_s, body: 'Article text').save
end
Article.order([ :title.desc, :body.asc ]).to_a.each {|result| puts result}
puts '-----------------------------------------------------'

# Филтриране по стойностите на един или повече атрибути (включително с неравенства)
puts '-----------------------------------------------------'
puts "Filter by value"
Article.where(:body.eql => 'Article text').to_a.each {|result| puts result}
puts '-----------------------------------------------------'

# Лимитиране на брой върнати резултати при заявка
puts '-----------------------------------------------------'
puts "First two"
      Article.limit(2).to_a.each {|result| puts result}
puts '-----------------------------------------------------'

# Пропускане на определен брой записи от заявка
puts '-----------------------------------------------------'
puts "Skip 3"
Article.limit(1).offset(3).to_a.each {|result| puts result}
puts '-----------------------------------------------------'

# Горните могат да се комбиринат и chain-ват
# (например, User.where(first_name: 'a').where(last_name: 'b').order(first_name: :desc))
puts '-----------------------------------------------------'
puts "Chain them"
Article.where(body: 'Article text').limit(2).order([ :title.desc ]).to_a.each {|result| puts result}
puts '-----------------------------------------------------'

# Да се поддържат прости агрегации като count и avg
puts '-----------------------------------------------------'
Article.count(body: 'Article text')
puts '-----------------------------------------------------'

# В доста от случаите моделите са свързани по някакъв начин.
# Например, един потребител може да има много коментари. Имплементирайте
# възможност за задаване поне на 1:1 и 1:N асоциации между моделите.
# Това означава че очакваме да можем да "свържем" две инстанции на модели в Ruby кода
# (например, user.comments = [Comment.new(...)]) и това да се отрази
# в базата от данни след като запишем инстанцията.
puts '-----------------------------------------------------'
 author = Author.new(name: 'John Doe')
 author.save()
 author.articles << article
 puts author.articles[0].title
puts '-----------------------------------------------------'
