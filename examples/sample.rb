require 'pathname'
require Pathname(__FILE__).dirname.expand_path.parent + 'lib/lazy_mapper'

LazyMapper.setup(:default,  'sqlite3::memory:')
#LazyMapper.setup(:default, 'postgres://postgres:test@localhost/testdb')
@adapter = repository(:default).adapter

# Възможност за логване на направените към базата
# от данни заявки. Този лог трябва да е конфигурируем по следния начин:
# Дали да логва на стандартния изход или във файл.
# Лог записи на различни нива - DEBUG, INFO, ERROR.
# Минимално ниво на лог записите, които да се виждат в лога.
LazyMapper::Logger.new(nil, :debug)

class Article
  include LazyMapper::Resource

  property :title, String, :key => true
  property :body,  String
end

class Author
  include LazyMapper::Resource

  property :name, String, :key => true
  has n, :articles
end

# Искаме да можем да свържем произволен написан от нас клас
# с таблица в база от данни, съдържаща колони за атрибутите
# на класа. Всеки такъв клас се нарича модел.
Article.auto_migrate!(:default)
Author.auto_migrate!(:default)
puts "Created table article: " + @adapter.storage_exists?("articles").to_s
puts "Created table author: " + @adapter.storage_exists?("authors").to_s

# Да се поддържа работа с поне 2 релационни бази от данни по
# ваш избор - например SQLite и PostgreSQL. Можете да използвате
# gem-ове като sqlite3 за комуникация със съответната база от данни.
# Нямате право да използвате наготово ORM библиотеки.

#LazyMapper.setup(:default, 'postgres://postgres:test@localhost/testdb')

# Създаване, четене, изтриване и ъпдейт (CRUD)
article = Article.new(:title => 'Firsrt Article', :body => 'Article text')
article.save()
puts Article.all
article.title = "Second Article"
article.save()
puts Article.all
article.destroy
puts Article.all

# Сортиране по произволни атрибути и в произволна посока (ascending/descending)
5.times do |time|
    Article.create(:title => 'Firsrt Article'  + time.to_s, :body => 'Article text')
end
puts Article.all
puts Article.all(:order => [ :title.desc ])

# Филтриране по стойностите на един или повече атрибути (включително с неравенства)
puts Article.all(:body => 'Article text')

# Лимитиране на брой върнати резултати при заявка
puts Article.all(:limit => 2)

# Пропускане на определен брой записи от заявка
puts Article.all(:limit => 2, :offset => 3)

# Горните могат да се комбиринат и chain-ват
# (например, User.where(first_name: 'a').where(last_name: 'b').order(first_name: :desc))
puts Article.all(:order => [ :title.desc ], :limit => 2)

# Да се поддържат прости агрегации като count и avg
puts Article.count(:body => 'Article text')

# В доста от случаите моделите са свързани по някакъв начин.
# Например, един потребител може да има много коментари. Имплементирайте
# възможност за задаване поне на 1:1 и 1:N асоциации между моделите.
# Това означава че очакваме да можем да "свържем" две инстанции на модели в Ruby кода
# (например, user.comments = [Comment.new(...)]) и това да се отрази
# в базата от данни след като запишем инстанцията.
author = Author.new(:name => 'John Doe')
author.save()
author.articles << article
puts author.articles[0].title
