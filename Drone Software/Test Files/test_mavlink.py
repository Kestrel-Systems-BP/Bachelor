import _asyncio
from mavlink import MAVLinkConnection

async def test_mavlink():
    try:
        mavlink = MAVLinkConnection()
        await mavlink.connect()
        await asyncio.sleep(2)
        await mavlink.disconnect()
        print("MAVLink test has passed")
    except Exception as e:
        print(f"MAVLink test has failed: {e}")

if __name__ == "__main__":
    asyncio.run(test_mavlink())
