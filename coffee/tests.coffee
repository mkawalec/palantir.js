spec = {
    base_url: 'http://localhost:8080/tests/'
}

test 'existence_test', ->
    ok window.palantir != undefined
    ok window.init != undefined
    ok window.singleton != undefined
    ok window.gettext == undefined
    ok window.cache == undefined
    ok window.template == undefined
    ok window.notifier == undefined
    ok window.helpers == undefined

test 'methods_existence', ->
    p = palantir(spec)
    ok p.route != undefined
    ok p.template != undefined
    ok p.extend_renderers != undefined
    ok p.route != undefined
    ok p.goto != undefined
    ok p.notifier != undefined
    ok p.helpers != undefined
    ok p.gettext != undefined

test 'extending_palantir', ->
    p = palantir(spec)
    test_method = () -> 'I am a test'

    ok p.test_method == undefined
    
    p2 = palantir(spec, {test_method: test_method})
    ok p2.test_method != undefined
    ok p2.test_method() == 'I am a test'

    p3 = palantir(spec)
    ok p3.test_method == undefined

test 'test_singleton', ->
    analyzed = singleton(()->
        value = null

        if value == null
            value = Math.random()

        return {value: value}
    )

    ok _.isEqual analyzed(), analyzed()

asyncTest 'test_gettext', ->
    p = palantir(spec)
    
    setTimeout((()->
        start()
        _ = p.gettext.gettext
        ok _ != undefined

        ok _('Hi') == 'Hi'
        ok _('Hi', 'pl') == 'Cześć'
        ok _('Hello', 'pl') == 'Witaj'
        ok _('Hi', 'es') == 'Hi'
        ok _('Don\'t know', 'pl') == 'Don\'t know'

    ), 0)

asyncTest 'Test notifier', ->
    p = palantir(spec)

    setTimeout((() ->
        start()
        p.notifier.notify({status: 500})
        ok $('#alerts')[0].children.length > 0
    ), 0)


asyncTest 'test_models', ->
    p = palantir(spec)
    test_model = p.model.init {
        id: 'string_id'
        url: 'http://localhost:5000/'
    }


    test_model.get (data) ->
        start()
        ok data[0].__dirty == false

        data[0].name = 'test'
        ok data[0].__dirty == true
        ok data[0].name == 'test'


asyncTest 'keys_test', ->
    p = palantir(spec)
    test_model = p.model.init {
        id: 'string_id'
        url: 'http://localhost:5000/'
    }

    test_model.new (new_obj)->
        start()
        new_obj.name = 'sdsd'
        ok new_obj.name == 'sdsd'
        stop()
        new_obj.__submit ->
            start()
            ok new_obj.name == 'sdsd'
            ok typeof new_obj.string_id == 'string'

asyncTest 'submit_delete_test', ->
    p = palantir(spec)
    test_model = p.model.init {
        id: 'string_id'
        url: 'http://localhost:5000/'
    }

    test_model.new (new_obj) ->
        start()
        new_obj.name = 'sdsd'
        stop()
        test_model.submit ->
            start()
            ok typeof new_obj.string_id == 'string'
            stop()

            new_obj.__delete ->
                start()
                try
                    typeof new_obj.string_id == undefined
                    ok false
                catch e
                    ok e.type == 'DeletedError'

test 'test_model_registration', ->
    p = palantir(spec)
    test_model = p.model.init {
        id: 'string_id'
        url: 'http://localhost:5000/'
    }
    test_model2 = p.model.init {
        id: 'string_id'
        url: 'http://localhost:5000/'
    }

    ok test_model._all_models().length > 1
    ok test_model2._all_models().length > 1


asyncTest 'Test object deletion by the Model', ->
    p = palantir(spec)
    test_model3 = p.model.init {
        id: 'string_id'
        url: 'http://localhost:5000/'
    }
    test_model3.new (new_obj) ->
        new_obj.name = 'sdadssad'

        test_model3.submit ->
            test_model3.delete new_obj, ->
                start()
                try
                    typeof new_obj.string_id == undefined
                    ok false
                catch e
                    ok e.type == 'DeletedError'

asyncTest 'Test routes', ->
    p = palantir(spec)

    p.helpers.delay ->
        p.route 'test_route', (what) ->
            start()
            ok true
            ok what == 'this is a test'
            stop()

        p.route 'click_test', (what) ->
            start()
            ok true
            ok what == link

        p.goto 'test_route', 'this is a test'

        id = p.helpers.random_string()
        $('body').append "<a href='#' style='display:none;' "+\
            "data-route='click_test' id='#{ id }'>Click!</a>"

        link = $("##{ id }")[0]
        link.click()


