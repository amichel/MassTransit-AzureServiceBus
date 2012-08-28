﻿// Copyright 2012 Henrik Feldt
//  
// Licensed under the Apache License, Version 2.0 (the "License"); you may not use 
// this file except in compliance with the License. You may obtain a copy of the 
// License at 
// 
//     http://www.apache.org/licenses/LICENSE-2.0 
// 
// Unless required by applicable law or agreed to in writing, software distributed 
// under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR 
// CONDITIONS OF ANY KIND, either express or implied. See the License for the 
// specific language governing permissions and limitations under the License.

using MassTransit.Logging;

namespace MassTransit.Transports.AzureServiceBus.Internal
{
	/// <summary>
	/// Extensions for logging to MassTransit.Messages
	/// </summary>
	public static class EndpointAsyncLoggerExtensions
	{
		static readonly ILog _messages = Logger.Get("MassTransit.Messages");

		/// <summary>
		/// Normal operation send
		/// </summary>
		public static void LogBeginSend(this IEndpointAddress sourceAddress, string messageId)
		{
			_messages.DebugFormat("SEND begin:{0}:{1}", sourceAddress, messageId);
		}

		/// <summary>
		/// Finished sending operation successfully
		/// </summary>
		public static void LogEndSend(this IEndpointAddress sourceAddress, string messageId)
		{
      _messages.DebugFormat("SEND end:{0}:{1}", sourceAddress, messageId);
		}

		/// <summary>
		/// Warns, this is not a good thing; means we're taxing the broker too much.
		/// </summary>
		public static void LogSendRetryScheduled(this IEndpointAddress sourceAddress, string messageId, int messagesInFlight, int inSleep)
		{
			_messages.WarnFormat("SEND retry:{0}:{1}. Messages in flight: {2}. Messages sleeping: {3} ", 
				sourceAddress, messageId, messagesInFlight, inSleep);
		}
	}
}