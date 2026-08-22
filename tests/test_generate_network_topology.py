import importlib.util
import unittest
from pathlib import Path

SCRIPT = Path(__file__).parents[1] / "docs" / "generate-network-topology.py"


class NetworkTopologyTest(unittest.TestCase):
    def test_renders_underlay_groups_and_wireguard_peers(self) -> None:
        spec = importlib.util.spec_from_file_location("generate_network_topology", SCRIPT)
        if spec is None or spec.loader is None:
            self.fail("could not load network topology generator")
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)

        data = {
            "hosts": {
                "eta": {
                    "ipv4": "203.0.113.10",
                    "gateway": "203.0.113.1",
                    "wg-admin": "10.100.0.1",
                    "wireguardEndpoint": None,
                    "tags": ["public-ip", "vps-network"],
                },
                "rho": {
                    "ipv4": "10.80.169.39",
                    "gateway": "10.80.169.254",
                    "wg-admin": "10.100.0.3",
                    "wireguardEndpoint": None,
                    "tags": ["nat-behind", "lab-network"],
                },
            },
            "wireguard": {
                "eta": {
                    "wg-admin": {
                        "peers": [
                            {"AllowedIPs": ["10.100.0.3/32"]},
                            {"AllowedIPs": ["10.100.0.200/32"]},
                        ]
                    }
                },
                "rho": {"wg-admin": {"peers": [{"AllowedIPs": ["10.100.0.1/32"]}]}},
            },
        }

        output = module.render_topology(data)

        self.assertIn('subgraph lab["연구실 네트워크 · NAT"]', output)
        self.assertIn('lab_gateway["연구실 게이트웨이<br/>10.80.169.254"]', output)
        self.assertIn("internet --> eta_under", output)
        self.assertIn("wg_eta --- wg_rho", output)
        self.assertEqual(output.count("wg_eta --- wg_rho"), 1)
        self.assertIn('wg_external_10_100_0_200["외부 peer<br/>10.100.0.200"]', output)
        self.assertIn("| eta | 203.0.113.10 | 203.0.113.1 | 10.100.0.1 |", output)


if __name__ == "__main__":
    unittest.main()
