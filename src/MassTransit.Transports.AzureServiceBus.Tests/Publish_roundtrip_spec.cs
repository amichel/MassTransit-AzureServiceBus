// Copyright 2012 Henrik Feldt
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

using System;
using Magnum.Extensions;
using Magnum.TestFramework;
using MassTransit.BusConfigurators;
using MassTransit.TestFramework;
using MassTransit.Transports.AzureServiceBus.Tests.Contexts;

namespace MassTransit.Transports.AzureServiceBus.Tests
{
	[Scenario, Integration]
	public class Publish_roundtrip_spec
		: Given_a_bus_context
	{
		private Future<A> _received;

		protected override void ConfigureServiceBus(Uri uri, ServiceBusConfigurator configurator)
		{
			base.ConfigureServiceBus(uri, configurator);

			_received = new Future<A>();

			configurator.Subscribe(s => 
				s.Handler<A>(message => _received.Complete(message)));
		}

		[When]
		public void A_message_is_published()
		{
			//Console.WriteLine("Inbound:");
			//PipelineViewer.Trace(LocalBus.InboundPipeline);

			//Console.WriteLine("Outbound:");
			//PipelineViewer.Trace(LocalBus.OutboundPipeline);

			// wait on the inbound to become ready so that it starts accepting subscriptions
			LocalBus.Endpoint.InboundTransport.Receive(c => cc => { }, 1.Milliseconds());

			LocalBus.Publish(new A
				{
					StringA = "ValueA",
				});
		}

		[Then]
		public void Should_be_received_by_the_queue()
		{
			_received.WaitUntilCompleted(3.Seconds()).ShouldBeTrue();
			_received.Value.StringA.ShouldEqual("ValueA");
		}

		private class A
		{
			public string StringA { get; set; }
		}
	}
}