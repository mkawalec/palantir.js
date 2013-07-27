from flask import (Flask, request, abort,
        jsonify, g, Response)
from werkzeug.exceptions import HTTPException

from sqlalchemy import create_engine
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import scoped_session, sessionmaker, state
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm.exc import NoResultFound

from sqlalchemy import Column, Integer, String, Sequence

import random

from datetime import datetime
import json

from crossdomain import crossdomain

engine = create_engine('sqlite:////tmp/palantir_tests.db')
db_session = scoped_session(sessionmaker(autocommit=False,
                                         autoflush=False,
                                         bind=engine))

Base = declarative_base()
Base.query = db_session.query_property()

CHARS = 'abcdefghijklmnoprstuwqxyzABCDEFGHIJKLMNOPRSTUWQXYZ0123456789'

class TestItem(Base):
    __tablename__ = 'tests'
    id = Column(Integer, Sequence('tests_id_seq'),
            primary_key=True)

    name = Column(String(400), nullable=True)
    string_id = Column(String(12), unique=True)

    def __init__(self, name=None):
        self.string_id = gen_filename()
        self.name = name

def init_db():
    Base.metadata.create_all(engine)

    for i in range(100):
        temp = TestItem(gen_filename())
        db_session.add(temp)
    db_session.commit()

def gen_filename(chars=12):
    return ''.join(random.sample(CHARS, chars))

def stringify_class(obj, one=None):
    restricted = ['id', 'disabled']
    if isinstance(obj, dict):
        ret = {}
        for el in obj:
            ret[el] = stringify_class(obj[el])
    elif isinstance(obj, list):
        ret = []
        for el in obj:
            ret.append(stringify_class(el))

    else:
        ret = {}
        for el in obj.__dict__:
            # We don't want to publish private ids
            if el in restricted or el[0] == '_':
                continue
            if isinstance(obj.__dict__[el], datetime):
                ret[el] = unicode(obj.__dict__[el])
            elif isinstance(obj.__dict__[el], state.InstanceState):
                continue
            elif isinstance(obj.__dict__[el], list):
                prop = []
                for element in obj.__dict__[el]:
                    prop.append(stringify_class(element))
                ret[el] = prop
            elif hasattr(obj.__dict__[el], '__dict__'):
                ret[el] = stringify_class(obj.__dict__[el])
            else:
                ret[el] = obj.__dict__[el]

    return ret

def class_spec(instance, restricted=[]):
    restricted.extend(['id', 'disabled'])

    ret = {}
    for key in instance.__dict__:
        if key not in restricted and key[0] != '_':
            ret[key] = instance.__dict__[key].__class__.__name__

    return ret

def abort_message(code, status, fields, validators):
    def get_methods():
        options_resp = app.make_default_options_response()
        return options_resp.headers['allow']

    payload = json.dumps(dict(status=status, fields=fields, validators=validators))

    h = dict()
    h['Access-Control-Allow-Origin'] = '*'
    h['Access-Control-Allow-Methods'] = get_methods()
    h['Access-Control-Max-Age'] = str(21600)

    resp = Response(payload, code, headers=h)
    raise HTTPException(response=resp)


app = Flask(__name__)

@app.route('/')
@crossdomain(origin='*')
def index():
    limit = request.args.get('limit')
    try:
        limit = int(limit)
        if limit > 30:
            limit = 30
    except (ValueError, TypeError):
        limit = 30

    ret = db_session.query(TestItem)    

    after = request.args.get('after')
    if after:
        stmt = db_session.query(TestItem).\
            filter(TestItem.string_id == after).subquery()

        ret = ret.\
                filter(TestItem.id > stmt.c.id)

    try:
        ret = ret.\
            order_by(TestItem.id).\
            limit(limit+1).\
            all()
    except NoResultFound:
        abort(409)

    if len(ret) == limit+1:
        more = True
    else:
        more = False

    return jsonify(data=stringify_class(ret), more=more)

@app.route('/spec/')
@crossdomain(origin='*')
def spec():
    ret = db_session.query(TestItem).first()
    return jsonify(data=class_spec(ret))

@app.route('/', methods=['POST'])
@crossdomain(origin='*')
def post():
    f = json.loads(request.form.get('data'))
    added = TestItem(f['name'])
    db_session.add(added)

    try:
        db_session.commit()
        added.string_id
        return jsonify(data=stringify_class(added))
    except IntegrityError:
        db_session.rollback()
        abort(500)

@app.route('/fail_post/', methods=['GET', 'POST', 'OPTIONS'])
@crossdomain(origin='*')
def fail_post():
    if request.method == 'GET':
        return index()

    f = json.loads(request.form.get('data'))
    abort_message(409, 'fieldError', 'name', 'not(%s)' % (f['name']))

@app.route('/fail_post/spec/')
@crossdomain(origin='*')
def fail_post_spec():
    return spec()

@app.route('/<id>', methods=['DELETE', 'OPTIONS'])
@crossdomain(origin='*')
def delete(id):
    try:
        item = db_session.query(TestItem).\
                filter(TestItem.string_id == id).\
                one()
    except NoResultFound:
        abort(404)

    db_session.delete(item)
    return jsonify(status='succ')

if __name__ == '__main__':
    init_db()
    app.run(debug=True)


