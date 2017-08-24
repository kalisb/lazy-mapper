require 'pathname'
require Pathname(__FILE__).dirname.expand_path.parent + 'lib/lazy_mapper'

# Възможност за логване на направените към базата
# от данни заявки. Този лог трябва да е конфигурируем по следния начин:
# Дали да логва на стандартния изход или във файл.
# Лог записи на различни нива - DEBUG, INFO, ERROR.
# Минимално ниво на лог записите, които да се виждат в лога.
LazyMapper::Logger.new($stdout, :info)

# Да се поддържа работа с поне 2 релационни бази от данни по
# ваш избор - например SQLite и PostgreSQL. Можете да използвате
# gem-ове като sqlite3 за комуникация със съответната база от данни.
# Нямате право да използвате наготово ORM библиотеки.
LazyMapper.establish_connection(:default, 'sqlite3:test.db')
#LazyMapper.establish_connection(:default, 'postgres://postgres:test@localhost/postgres')
