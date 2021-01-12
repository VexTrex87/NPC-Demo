return function(animator: instance, animation: instance): instance
    if animator and animation then
        return animator:LoadAnimation(animation)
    end
end