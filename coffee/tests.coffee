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
    ok p.templates != undefined
    ok p.templates.extend_renderers != undefined
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
            try
                new_obj.string_id = 'this should fail'
                ok false
            catch e
                ok e.type == 'ValueError'

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

    ok p.model._all_models().length > 1
    ok p.model._all_models().length > 1


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
    console.log spec
    p = palantir(_.extend spec, {blah: 'bam'})
    console.log 'test init'

    p.helpers.delay ->
        console.log 'delay'
        p.route 'test_route', (params) ->
            console.log 'starting'
            if QUnit.config.semaphore > 0
                start()
            ok true
            ok params['test_param'] == 'this is a test'

            ok params['param1'] == 'test1'
            ok params['param2'] == 'test2'
            stop()

        p.route 'click_test', (params) ->
            if QUnit.config.semaphore > 0
                start()
            ok true
            ok params['target'] == $(link).attr 'id'
            ok params['param1'] == 'test'

        p.goto 'test_route?param1=test1&param2=test2', {test_param: 'this is a test'}

        id = p.helpers.random_string()
        $('body').append "<a href='#' style='display:none;' "+\
            "data-route='click_test?param1=test' id='#{ id }'>Click!</a>"

        link = $("##{ id }")[0]
        link.click()

asyncTest 'Parallel test', ->
    singleton.prototype = {}
    p = palantir(_.extend spec, {max_requests: 1})

    p.open {
        url: 'http://localhost:5000/?q='+p.helpers.random_string()
        success: ->
            start()
            ok true
            stop()
        error: (data) ->
            start()
            ok false
            stop()
    }

    p.open {
        url: 'http://localhost:5000/?q='+p.helpers.random_string()
        success: ->
            start()
            ok true
            singleton.prototype = {}
        error: ->
            start()
            ok false
    }

    p.open {
        url: 'http://localhost:5000/?q='+p.helpers.random_string()
        success: ->
            start()
            ok true
            stop()
        error: (data) ->
            start()
            ok false
            stop()
    }

asyncTest 'Validator test', ->
    p = palantir(spec)

    p.helpers.delay ->
        start()
        ok p.validators?
        p.validators.init()

        for key,value of p.validators.test()
            ok value[0].errors[0] == 'This field is obligatory'

        $('body').append "<div class='form'>"+\
            "<button class='btn' data-submit='true' id='form_submitter'>Zapisz</button>"+\
            "<input type='text' data-validators='required' id='req_field'/></div>"
        p.validators.init()
        ok _.keys(p.validators.test()).length == 2

        $('#req_field')[0].value = 'dasdasdsa'
        $('#form_submitter')[0].click()

test_display_method = (spec={}, that={}) ->
    that.hide = ->
        return
    
    that.create = (errors, current_id) ->
        return

    return that

asyncTest 'Field failing test', ->
    p = palantir(spec)

    test_model = p.model.init {
        id: 'string_id'
        url: 'http://localhost:5000/fail_post/'
    }

    p.validators.extend_display_methods {
        test_method: test_display_method()
    }

    p.helpers.delay ->
        $('body').append "<input type='text' data-binding='name' id='namefield'/>"
        $('#namefield')[0].value = 'this is a name'
        test_model.new (new_obj) ->
            new_obj.name = $('#namefield')[0].value 
            test_model.submit ->
                start()
                ok true

asyncTest 'refresh test', ->
    p = palantir(spec)

    func = p.route 'test0', (params) ->
        if QUnit.config.semaphore > 0
            start()
        ok true
        
        if params.test?
            if params.test == 'right'
                ok true
            else
                ok false

        if not (params.blah? and params.blah == 'test')
            stop()


    p.goto p.route_for func
    p.refresh()
    p.helpers.delay ->
        p.goto '__refresh?test=right'

    p.helpers.delay ->
        p.refresh({blah: 'test'})


