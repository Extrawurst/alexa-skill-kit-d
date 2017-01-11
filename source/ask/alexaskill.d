module ask.alexaskill;

import vibe.d;

import ask.types;
import ask.locale;

/// annotation to mark an intent callback, use name to specify the exact intent name as specified in the intent schema
struct CustomIntent
{
	///
	string name;
}

///
abstract class AlexaSkill(T)
{
	///
	private AlexaText[] localeText;

	/++ 
	 + constructor that requires the loca table as input
	 +
	 + params:
	 +   text = loca table to use for that request
	 +
	 + see_also:
	 +  `AlexaText`, `LocaParser` 
	 +/	
	this(AlexaText[] text)
	{
		localeText = text;
	}

	///
	int execute(AlexaEvent event, AlexaContext context, Duration timeout = 2.seconds)
	{
		import std.stdio:writeln,stderr;

		runTask({
			scope(exit) exitEventLoop();

			stderr.writefln("execute request: %s",event.request.type);

			AlexaResult result;

			if(event.request.type == AlexaRequest.Type.LaunchRequest)
				result = onLaunch(event, context);
			else if(event.request.type == AlexaRequest.Type.IntentRequest)
				result = onIntent(event, context);
			else if(event.request.type == AlexaRequest.Type.SessionEndedRequest)
				onSessionEnd(event, context);

			writeln(serializeToJson(result).toPrettyString());
		});

		setTimer(timeout, {
			writeln("{}");
			stderr.writeln("intent timeout");
			exitEventLoop();
		});

		return runEventLoop();
	}

	/// returns the 
	string getText(int _key) const pure nothrow
	{
		return localeText[_key].text;
	}

	/// see https://developer.amazon.com/public/solutions/alexa/alexa-skills-kit/docs/custom-standard-request-types-reference#launchrequest
	AlexaResult onLaunch(AlexaEvent, AlexaContext)
	{
		throw new Exception("not implemented");
	}

	/// see https://developer.amazon.com/public/solutions/alexa/alexa-skills-kit/docs/custom-standard-request-types-reference#intentrequest
	AlexaResult onIntent(AlexaEvent event, AlexaContext context)
	{
		import std.traits:hasUDA,getUDAs;

		foreach(i, member; __traits(derivedMembers, T))
		{
			enum isPublic = __traits(getProtection, __traits(getMember, cast(T)this, member)) == "public";

			static if(isPublic && hasUDA!(__traits(getMember, T, member), CustomIntent))
			{
				enum name = getUDAs!(__traits(getMember, T, member), CustomIntent)[0].name;
				
				if(event.request.intent.name == name)
				{
					mixin("return (cast(T)this)."~member~"(event, context);");
				}
			}
		}

		import std.stdio:stderr;
		stderr.writefln("onIntent did not match: %s",event);
		return AlexaResult();
	}

	/// see https://developer.amazon.com/public/solutions/alexa/alexa-skills-kit/docs/custom-standard-request-types-reference#sessionendedrequest
	void onSessionEnd(AlexaEvent, AlexaContext)
	{
		throw new Exception("not implemented");
	}
}
