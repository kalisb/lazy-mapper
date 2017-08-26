require 'pathname'
require Pathname(__FILE__).dirname.expand_path.parent + 'lib/lazy_mapper'

# Възможност за логване на направените към базата
# от данни заявки. Този лог трябва да е конфигурируем по следния начин:
# Дали да логва на стандартния изход или във файл.
# Лог записи на различни нива - DEBUG, INFO, ERROR.
# Минимално ниво на лог записите, които да се виждат в лога.
logger = LazyMapper::Logger.new($stdout, :info)

# Да се поддържа работа с поне 2 релационни бази от данни по
# ваш избор - например SQLite и PostgreSQL. Можете да използвате
# gem-ове като sqlite3 за комуникация със съответната база от данни.
# Нямате право да използвате наготово ORM библиотеки.
LazyMapper.establish_connection(:default, 'sqlite3:test.db')
# LazyMapper.establish_connection(:default, 'postgres://postgres:test@localhost/postgres')

class Article < LazyMapper::Model
  property :id, Integer, serial: true
  property :title, String
  property :body,  String
  has 1, :author
end

class Author < LazyMapper::Model
  property :id, Integer, serial: true
  property :name, String
  has n, :articles
end

# Искаме да можем да свържем произволен написан от нас клас
# с таблица в база от данни, съдържаща колони за атрибутите
# на класа. Всеки такъв клас се нарича модел.
logger.info "Create tables"
Author.create_table(:default)
Article.create_table(:default)
Author.update_table(:default)

# Създаване, четене, изтриване и ъпдейт (CRUD)
logger.info "Use CRUD operations"
article = Article.new(title: 'First Article', body: 'Article text')
article.save
logger.info "Create article"
logger.info "Articles count: #{Article.count} with title #{Article.first.title}"
article.title = "Second Article"
article.update
logger.info "Update tables"
logger.info "Articles count: #{Article.count} with title #{Article.first.title}"
article.destroy
logger.info "Delete tables"
logger.info "Articles count: #{Article.count}"

# Сортиране по произволни атрибути и в произволна посока (ascending/descending)
5.times do |time|
  Article.new(title: 'Firsrt Article' + time.to_s, body: 'Article text').save
end
logger.info "Ordered set:"
Article.order([ :title.desc, :body.asc ]).to_a.each { |result| puts result.title }

# Филтриране по стойностите на един или повече атрибути (включително с неравенства)
logger.info "Filter by value"
Article.where(:body.eql => 'Article text').to_a.each { |result| puts result.title }

# Лимитиране на брой върнати резултати при заявка
logger.info "First two"
      Article.limit(2).to_a.each { |result| puts result.title }

# Пропускане на определен брой записи от заявка
logger.info "Skip 3"
Article.limit(1).offset(3).to_a.each { |result| puts result.title }

# Горните могат да се комбиринат и chain-ват
# (например, User.where(first_name: 'a').where(last_name: 'b').order(first_name: :desc))
logger.info "Chain them"
Article.where(body: 'Article text').limit(2).order([ :title.desc ]).to_a.each { |result| puts result.title }

# Да се поддържат прости агрегации като count и avg
logger.info 'Use count'
logger.info "Articles count :#{Article.count(body: 'Article text')}"

# В доста от случаите моделите са свързани по някакъв начин.
# Например, един потребител може да има много коментари. Имплементирайте
# възможност за задаване поне на 1:1 и 1:N асоциации между моделите.
# Това означава че очакваме да можем да "свържем" две инстанции на модели в Ruby кода
# (например, user.comments = [Comment.new(...)]) и това да се отрази
# в базата от данни след като запишем инстанцията.
logger.info "Has 1 and has many"
author = Author.new(name: 'John Doe')
author.articles << article
author.save
logger.info Author.first.articles
