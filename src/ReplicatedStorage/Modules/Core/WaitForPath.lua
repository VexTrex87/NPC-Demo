local BAD_ARG_ERROR="%s is not a valid %s"

return function(target, path, maxWait)
	do --error checking
		local tt=typeof(target)
		local tp=typeof(path)
		local tm=typeof(maxWait)

		if tt~="Instance" then 
			error(BAD_ARG_ERROR:format("Argument 1","Instance")) 
		end

		if tp~="string" then 
			error(BAD_ARG_ERROR:format("Argument 2","string")) 
		end

		if tm~="nil" and tm~="number" then 
			error(BAD_ARG_ERROR:format("Argument 3","number")) 
		end
	end

	local segments=string.split(path,".")
	local latest
	local start=tick()
	for _,segment in pairs(segments) do
		if maxWait then
			latest=target:WaitForChild(segment,(start+maxWait)-tick())
		else
			latest=target:WaitForChild(segment)
		end
		if latest then
			target=latest
		else
			return nil
		end
	end
	return latest
end