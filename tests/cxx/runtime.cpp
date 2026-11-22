#include <iostream>
#include <fstream>
#include <thread>
#include <mutex>
#include <atomic>
#include <memory>
#include <chrono>
#include <random>
#include <filesystem>
#include <regex>
#include <functional>
#include <unordered_map>
#include <cmath>
struct B{virtual ~B(){} virtual int f(){return 1;}}; struct D:B{int f() override {return 2;}};
int main(){
  std::atomic<int> n{0}; std::mutex m; std::vector<std::thread> th;
  for(int i=0;i<4;i++) th.emplace_back([&]{ for(int k=0;k<1000;k++){ std::lock_guard<std::mutex> g(m); n++; } });
  for(auto&t:th) t.join();
  std::unique_ptr<B> p(new D); auto* d=dynamic_cast<D*>(p.get());
  std::mt19937 rng(std::random_device{}()); 
  auto t0=std::chrono::steady_clock::now();
  std::ofstream("/tmp/cpp_t2.txt") << "line\n"; std::ifstream in("/tmp/cpp_t2.txt"); std::string s; std::getline(in,s);
  bool fs=std::filesystem::exists("/tmp/cpp_t2.txt");
  std::regex re("l(i)ne"); bool rx=std::regex_match(s,re);
  std::unordered_map<int,double> um{{1,std::sqrt(2.0)}};
  try{ throw std::runtime_error("boom"); }catch(const std::exception&e){ std::cout<<"caught "<<e.what()<<"\n"; }
  auto dt=std::chrono::steady_clock::now()-t0;
  std::cout<<"threads "<<n<<" dyncast "<<(d!=nullptr)<<" fs "<<fs<<" regex "<<rx<<" sqrt "<<um[1]<<" rng "<<(rng()!=0)<<" us "<<std::chrono::duration_cast<std::chrono::microseconds>(dt).count()<<"\n";
}
